# Zen Companion (iOS)

`ios/ZenCompanion` is a Swift Package-based native iOS companion app shell for this repository.

## What it includes

- **SwiftUI iOS app target (`ZenCompanionApp`)** with:
  - Home/start surface with address/search field and quick actions
  - Browser shell using `WKWebView`
  - Tab list and tab switching for the current Zen-style **Space**
  - Library surfaces for **Bookmarks** and **History**
  - Settings/Account view with sync status, offline/error states, and preferences
- **Core library (`ZenCompanionCore`)** with:
  - Codable models for tabs, workspaces (spaces), bookmarks, history, preferences
  - Protocol-based sync abstraction (`BrowserSyncService`)
  - Local/mock sync implementation (`MockBrowserSyncService`)
  - State controller with conflict strategy support (`serverWins`, `clientWins`, `latestWriteWins`)
- **Unit tests** for sync serialization and state behavior

## Visual and product alignment

The app mirrors Zen terminology and concepts (Spaces, tabs, Library, sync status) and uses a Zen-inspired accent (`#6473FF`) and neutral dark/light styling aligned with repository theme tokens such as `--zen-branding-dark`, `--zen-branding-paper`, and Zen workspace/sync concepts.

## Build and run

### Prerequisites

- Xcode 16+
- iOS 17+ simulator or device

### Open and run

1. Open `ios/ZenCompanion/Package.swift` in Xcode.
2. Select the `ZenCompanionApp` scheme.
3. Choose an iPhone or iPad simulator.
4. Build and Run.

## Sync architecture and integration points

Current implementation intentionally uses a mock/local sync backend to avoid inventing an incompatible production service.

### Existing desktop assumptions considered

- Desktop code syncs Spaces/workspace-like structures and tabs through dedicated sync models/engines (`src/zen/sync/*`) and tracks containers, spaces, tabs, folders, splits, and layout records.
- This iOS companion maps the mobile shell to compatible high-value state: workspaces/spaces, tabs, bookmarks, history, and preferences.

### Integration contract

`BrowserSyncService` defines two operations:

- `fetchRemoteState()` to pull latest synchronized state
- `push(localState:lastKnownRemoteVersion:)` to upload local snapshot and receive canonical remote envelope

To integrate with a real service, replace `MockBrowserSyncService` with an implementation that:

1. Authenticates against the chosen account system.
2. Serializes/deserializes `SyncEnvelope` to the production protocol.
3. Maps Zen desktop sync records to `BrowserState` fields.
4. Honors conflict strategy and versioning semantics.
5. Reports network/auth/server errors via `BrowserSyncError`.

## State handling

The UI reports and handles:

- **Loading/syncing** (`ProgressView`)
- **Offline** status
- **Error** status with message
- **Empty** tabs/bookmarks/history states
- **Last-synced** timestamp

## Known limitations in this environment

- This sandbox cannot produce a signed `.ipa`.
- iOS simulator/device execution cannot be verified here.
- The mock sync path is local-only by design; production endpoints/auth are intentionally abstracted.
