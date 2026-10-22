import Foundation

public struct BrowserTab: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var url: URL
    public var isPinned: Bool
    public var lastVisitedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        isPinned: Bool = false,
        lastVisitedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.isPinned = isPinned
        self.lastVisitedAt = lastVisitedAt
    }
}

public struct Workspace: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var icon: String
    public var tabs: [BrowserTab]
    public var selectedTabID: BrowserTab.ID?

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "square.grid.2x2",
        tabs: [BrowserTab] = [],
        selectedTabID: BrowserTab.ID? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.tabs = tabs
        self.selectedTabID = selectedTabID ?? tabs.first?.id
    }

    public var selectedTab: BrowserTab? {
        guard let selectedTabID else { return tabs.first }
        return tabs.first(where: { $0.id == selectedTabID }) ?? tabs.first
    }
}

public struct BookmarkItem: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var url: URL
    public var createdAt: Date

    public init(id: UUID = UUID(), title: String, url: URL, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.url = url
        self.createdAt = createdAt
    }
}

public struct HistoryItem: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var url: URL
    public var visitedAt: Date

    public init(id: UUID = UUID(), title: String, url: URL, visitedAt: Date = .now) {
        self.id = id
        self.title = title
        self.url = url
        self.visitedAt = visitedAt
    }
}

public struct BrowserPreferences: Codable, Equatable, Sendable {
    public var usesDarkTheme: Bool
    public var syncOnCellular: Bool

    public init(usesDarkTheme: Bool = false, syncOnCellular: Bool = true) {
        self.usesDarkTheme = usesDarkTheme
        self.syncOnCellular = syncOnCellular
    }
}

public struct BrowserState: Codable, Equatable, Sendable {
    public var workspaces: [Workspace]
    public var selectedWorkspaceID: Workspace.ID?
    public var bookmarks: [BookmarkItem]
    public var history: [HistoryItem]
    public var preferences: BrowserPreferences

    public init(
        workspaces: [Workspace],
        selectedWorkspaceID: Workspace.ID? = nil,
        bookmarks: [BookmarkItem] = [],
        history: [HistoryItem] = [],
        preferences: BrowserPreferences = .init()
    ) {
        self.workspaces = workspaces
        self.selectedWorkspaceID = selectedWorkspaceID ?? workspaces.first?.id
        self.bookmarks = bookmarks
        self.history = history
        self.preferences = preferences
    }

    public static var `default`: BrowserState {
        let startTab = BrowserTab(title: "Zen Home", url: URL(string: "https://zen-browser.app")!, isPinned: true)
        let workspace = Workspace(name: "Personal", icon: "person", tabs: [startTab], selectedTabID: startTab.id)
        return BrowserState(workspaces: [workspace], selectedWorkspaceID: workspace.id)
    }

    public var selectedWorkspace: Workspace? {
        guard let selectedWorkspaceID else { return workspaces.first }
        return workspaces.first(where: { $0.id == selectedWorkspaceID }) ?? workspaces.first
    }
}

public enum SyncConflictStrategy: String, Codable, CaseIterable, Sendable {
    case serverWins
    case clientWins
    case latestWriteWins
}

public struct SyncEnvelope: Codable, Equatable, Sendable {
    public var version: String
    public var updatedAt: Date
    public var sourceDeviceName: String
    public var state: BrowserState

    public init(
        version: String,
        updatedAt: Date = .now,
        sourceDeviceName: String,
        state: BrowserState
    ) {
        self.version = version
        self.updatedAt = updatedAt
        self.sourceDeviceName = sourceDeviceName
        self.state = state
    }
}

public enum SyncStatus: Equatable, Sendable {
    case idle(lastSynced: Date?)
    case syncing(lastSynced: Date?)
    case offline(lastSynced: Date?)
    case failed(message: String, lastSynced: Date?)

    public var lastSynced: Date? {
        switch self {
        case .idle(let date), .syncing(let date), .offline(let date), .failed(_, let date):
            return date
        }
    }
}

public enum BrowserSyncError: Error, Equatable, LocalizedError, Sendable {
    case offline
    case invalidPayload
    case server(String)

    public var errorDescription: String? {
        switch self {
        case .offline:
            return "You are offline. Connect to the internet and try syncing again."
        case .invalidPayload:
            return "The sync payload could not be decoded."
        case .server(let message):
            return message
        }
    }
}
