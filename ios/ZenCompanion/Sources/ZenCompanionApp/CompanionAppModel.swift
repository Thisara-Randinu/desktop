#if canImport(SwiftUI) && canImport(WebKit)
import Foundation
import SwiftUI
import ZenCompanionCore

@MainActor
final class CompanionAppModel: ObservableObject {
    @Published private(set) var state: BrowserState
    @Published private(set) var syncStatus: SyncStatus = .idle(lastSynced: nil)
    @Published var addressInput = ""

    private var controller: BrowserStateController
    private let syncService: MockBrowserSyncService
    private var lastLocalWriteDate: Date = .now

    init(
        initialState: BrowserState = .default,
        syncService: MockBrowserSyncService = MockBrowserSyncService(initialState: .default)
    ) {
        self.controller = BrowserStateController(state: initialState)
        self.state = initialState
        self.syncService = syncService
        self.addressInput = initialState.selectedWorkspace?.selectedTab?.url.absoluteString ?? ""
    }

    var selectedWorkspace: Workspace? {
        state.selectedWorkspace
    }

    var selectedTab: BrowserTab? {
        selectedWorkspace?.selectedTab
    }

    func selectWorkspace(_ workspaceID: Workspace.ID) {
        controller.selectWorkspace(workspaceID)
        publishState()
    }

    func selectTab(_ tabID: BrowserTab.ID) {
        controller.selectTab(tabID)
        publishState()
    }

    func closeTab(_ tabID: BrowserTab.ID) {
        controller.closeTab(tabID)
        publishState()
    }

    func openAddressInput() {
        guard !addressInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let resolvedURL = resolvedURL(from: addressInput)
        let tab = BrowserTab(title: titleForURL(resolvedURL), url: resolvedURL)
        controller.addTab(tab)
        controller.addHistory(title: tab.title, url: resolvedURL)
        lastLocalWriteDate = .now
        publishState()
    }

    func open(_ url: URL, title: String) {
        let tab = BrowserTab(title: title, url: url)
        controller.addTab(tab)
        controller.addHistory(title: title, url: url)
        lastLocalWriteDate = .now
        publishState()
    }

    func bookmarkSelectedTab() {
        guard let tab = selectedTab else { return }
        controller.addBookmark(from: tab)
        lastLocalWriteDate = .now
        publishState()
    }

    func toggleDarkMode(_ enabled: Bool) {
        state.preferences.usesDarkTheme = enabled
        controller = BrowserStateController(state: state, metadata: controller.metadata)
        lastLocalWriteDate = .now
        publishState()
    }

    func toggleSyncOnCellular(_ enabled: Bool) {
        state.preferences.syncOnCellular = enabled
        controller = BrowserStateController(state: state, metadata: controller.metadata)
        lastLocalWriteDate = .now
        publishState()
    }

    func setSyncModeOffline() {
        Task { await syncService.setMode(.offline) }
        syncStatus = .offline(lastSynced: syncStatus.lastSynced)
    }

    func setSyncModeError() {
        Task { await syncService.setMode(.fail(message: "Mock service returned an error.")) }
        syncStatus = .failed(message: "Mock service returned an error.", lastSynced: syncStatus.lastSynced)
    }

    func setSyncModeNormal() {
        Task { await syncService.setMode(.normal) }
        syncStatus = .idle(lastSynced: syncStatus.lastSynced)
    }

    func syncNow() async {
        syncStatus = .syncing(lastSynced: syncStatus.lastSynced)

        do {
            let pushed = try await syncService.push(
                localState: state,
                lastKnownRemoteVersion: controller.metadata.lastKnownRemoteVersion
            )
            controller.didSync(to: pushed)

            let remote = try await syncService.fetchRemoteState()
            controller.applyRemote(remote, localWriteDate: lastLocalWriteDate, strategy: .latestWriteWins)

            state = controller.state
            syncStatus = .idle(lastSynced: controller.metadata.lastSyncedAt)
        } catch let error as BrowserSyncError {
            switch error {
            case .offline:
                syncStatus = .offline(lastSynced: syncStatus.lastSynced)
            default:
                syncStatus = .failed(message: error.localizedDescription, lastSynced: syncStatus.lastSynced)
            }
        } catch {
            syncStatus = .failed(message: error.localizedDescription, lastSynced: syncStatus.lastSynced)
        }
    }

    func recordPageVisit(url: URL, title: String) {
        controller.addHistory(title: title, url: url)
        lastLocalWriteDate = .now
        publishState()
    }

    private func publishState() {
        state = controller.state
        addressInput = selectedTab?.url.absoluteString ?? ""
    }

    private func resolvedURL(from input: String) -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = URL(string: trimmed), direct.scheme != nil {
            return direct
        }

        if let https = URL(string: "https://\(trimmed)") {
            return https
        }

        let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://duckduckgo.com/?q=\(query)")!
    }

    private func titleForURL(_ url: URL) -> String {
        if let host = url.host, !host.isEmpty {
            return host
        }
        return url.absoluteString
    }
}
#endif
