import Foundation

public protocol BrowserSyncService: Sendable {
    func fetchRemoteState() async throws -> SyncEnvelope
    func push(localState: BrowserState, lastKnownRemoteVersion: String?) async throws -> SyncEnvelope
}

public actor MockBrowserSyncService: BrowserSyncService {
    public enum Mode: Sendable {
        case normal
        case offline
        case fail(message: String)
    }

    private var mode: Mode
    private let storeURL: URL
    private var fallbackEnvelope: SyncEnvelope

    public init(
        mode: Mode = .normal,
        initialState: BrowserState = .default,
        fileManager: FileManager = .default
    ) {
        self.mode = mode
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        self.storeURL = appSupport.appendingPathComponent("zen-companion-sync.json")
        self.fallbackEnvelope = SyncEnvelope(version: "1", sourceDeviceName: "Desktop Mock", state: initialState)
    }

    public func setMode(_ mode: Mode) {
        self.mode = mode
    }

    public func fetchRemoteState() async throws -> SyncEnvelope {
        try evaluateMode()
        if let persisted = try? loadPersistedEnvelope() {
            return persisted
        }
        return fallbackEnvelope
    }

    public func push(localState: BrowserState, lastKnownRemoteVersion: String?) async throws -> SyncEnvelope {
        try evaluateMode()
        let remote = (try? loadPersistedEnvelope()) ?? fallbackEnvelope

        let incomingVersion = Int(remote.version) ?? 0
        let localVersion = Int(lastKnownRemoteVersion ?? "0") ?? 0
        let nextVersion = String(max(incomingVersion, localVersion) + 1)

        let merged = SyncEnvelope(
            version: nextVersion,
            updatedAt: .now,
            sourceDeviceName: "iOS Companion",
            state: localState
        )

        try persist(merged)
        return merged
    }

    private func evaluateMode() throws {
        switch mode {
        case .normal:
            return
        case .offline:
            throw BrowserSyncError.offline
        case .fail(let message):
            throw BrowserSyncError.server(message)
        }
    }

    private func persist(_ envelope: SyncEnvelope) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)

        let directory = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: storeURL, options: .atomic)
        fallbackEnvelope = envelope
    }

    private func loadPersistedEnvelope() throws -> SyncEnvelope {
        let data = try Data(contentsOf: storeURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SyncEnvelope.self, from: data)
    }
}
