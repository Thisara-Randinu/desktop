import Foundation

public struct SyncMetadata: Equatable, Sendable {
    public var lastKnownRemoteVersion: String?
    public var lastSyncedAt: Date?

    public init(lastKnownRemoteVersion: String? = nil, lastSyncedAt: Date? = nil) {
        self.lastKnownRemoteVersion = lastKnownRemoteVersion
        self.lastSyncedAt = lastSyncedAt
    }
}

public struct BrowserStateController: Sendable {
    public private(set) var state: BrowserState
    public private(set) var metadata: SyncMetadata

    public init(state: BrowserState = .default, metadata: SyncMetadata = .init()) {
        self.state = state
        self.metadata = metadata
    }

    public mutating func selectWorkspace(_ id: Workspace.ID) {
        guard state.workspaces.contains(where: { $0.id == id }) else { return }
        state.selectedWorkspaceID = id
    }

    public mutating func addTab(_ tab: BrowserTab, workspaceID: Workspace.ID? = nil) {
        guard let workspaceIndex = resolveWorkspaceIndex(for: workspaceID) else { return }
        state.workspaces[workspaceIndex].tabs.append(tab)
        state.workspaces[workspaceIndex].selectedTabID = tab.id
    }

    public mutating func closeTab(_ tabID: BrowserTab.ID, workspaceID: Workspace.ID? = nil) {
        guard let workspaceIndex = resolveWorkspaceIndex(for: workspaceID) else { return }
        var workspace = state.workspaces[workspaceIndex]
        workspace.tabs.removeAll { $0.id == tabID }
        if workspace.selectedTabID == tabID {
            workspace.selectedTabID = workspace.tabs.first?.id
        }
        state.workspaces[workspaceIndex] = workspace
    }

    public mutating func selectTab(_ tabID: BrowserTab.ID, workspaceID: Workspace.ID? = nil) {
        guard let workspaceIndex = resolveWorkspaceIndex(for: workspaceID) else { return }
        guard state.workspaces[workspaceIndex].tabs.contains(where: { $0.id == tabID }) else { return }
        state.workspaces[workspaceIndex].selectedTabID = tabID
    }

    public mutating func addBookmark(from tab: BrowserTab) {
        guard !state.bookmarks.contains(where: { $0.url == tab.url }) else { return }
        state.bookmarks.insert(BookmarkItem(title: tab.title, url: tab.url), at: 0)
    }

    public mutating func addHistory(title: String, url: URL, visitedAt: Date = .now) {
        state.history.removeAll(where: { $0.url == url })
        state.history.insert(HistoryItem(title: title, url: url, visitedAt: visitedAt), at: 0)
        state.history = Array(state.history.prefix(250))
    }

    public mutating func applyRemote(
        _ remote: SyncEnvelope,
        localWriteDate: Date,
        strategy: SyncConflictStrategy
    ) {
        switch strategy {
        case .serverWins:
            state = remote.state
        case .clientWins:
            break
        case .latestWriteWins:
            if remote.updatedAt >= localWriteDate {
                state = remote.state
            }
        }

        metadata.lastKnownRemoteVersion = remote.version
        metadata.lastSyncedAt = remote.updatedAt
    }

    public mutating func didSync(to envelope: SyncEnvelope) {
        metadata.lastKnownRemoteVersion = envelope.version
        metadata.lastSyncedAt = envelope.updatedAt
    }

    private func resolveWorkspaceIndex(for workspaceID: Workspace.ID?) -> Int? {
        let fallbackID = state.selectedWorkspaceID ?? state.workspaces.first?.id
        let targetID = workspaceID ?? fallbackID
        guard let targetID else { return nil }
        return state.workspaces.firstIndex(where: { $0.id == targetID })
    }
}
