import Foundation
import XCTest
@testable import ZenCompanionCore

final class ZenCompanionCoreTests: XCTestCase {
    func testSyncEnvelopeRoundTrip() throws {
        let state = BrowserState.default
        let envelope = SyncEnvelope(version: "42", sourceDeviceName: "Desktop", state: state)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(envelope)
        let decoded = try decoder.decode(SyncEnvelope.self, from: data)

        XCTAssertEqual(decoded.version, envelope.version)
        XCTAssertEqual(decoded.sourceDeviceName, envelope.sourceDeviceName)
        XCTAssertEqual(decoded.state.workspaces.map(\.name), envelope.state.workspaces.map(\.name))
        XCTAssertEqual(decoded.state.workspaces.first?.tabs.first?.url, envelope.state.workspaces.first?.tabs.first?.url)
        XCTAssertEqual(decoded.state.preferences, envelope.state.preferences)
    }

    func testStateControllerTabLifecycleAndHistory() {
        var controller = BrowserStateController(state: .default)
        let workspaceID = controller.state.selectedWorkspaceID
        let addedTab = BrowserTab(title: "Example", url: URL(string: "https://example.com")!)

        controller.addTab(addedTab, workspaceID: workspaceID)
        controller.selectTab(addedTab.id, workspaceID: workspaceID)
        controller.addHistory(title: "Example", url: addedTab.url)

        XCTAssertEqual(controller.state.selectedWorkspace?.selectedTabID, addedTab.id)
        XCTAssertEqual(controller.state.history.first?.url, addedTab.url)

        controller.closeTab(addedTab.id, workspaceID: workspaceID)
        XCTAssertFalse(controller.state.selectedWorkspace?.tabs.contains(where: { $0.id == addedTab.id }) ?? true)
    }

    func testLatestWriteWinsConflictResolution() {
        let localTab = BrowserTab(title: "Local", url: URL(string: "https://local.dev")!)
        let remoteTab = BrowserTab(title: "Remote", url: URL(string: "https://remote.dev")!)

        var local = BrowserStateController(state: BrowserState(workspaces: [Workspace(name: "Personal", tabs: [localTab])]))
        let remoteState = BrowserState(workspaces: [Workspace(name: "Personal", tabs: [remoteTab])])
        let olderRemote = SyncEnvelope(version: "1", updatedAt: .distantPast, sourceDeviceName: "Desktop", state: remoteState)
        let newerRemote = SyncEnvelope(version: "2", updatedAt: .distantFuture, sourceDeviceName: "Desktop", state: remoteState)

        local.applyRemote(olderRemote, localWriteDate: .now, strategy: .latestWriteWins)
        XCTAssertEqual(local.state.workspaces.first?.tabs.first?.title, "Local")

        local.applyRemote(newerRemote, localWriteDate: .now, strategy: .latestWriteWins)
        XCTAssertEqual(local.state.workspaces.first?.tabs.first?.title, "Remote")
    }
}
