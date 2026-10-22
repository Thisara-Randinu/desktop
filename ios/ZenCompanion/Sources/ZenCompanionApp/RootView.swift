#if canImport(SwiftUI) && canImport(WebKit)
import SwiftUI
import ZenCompanionCore

private enum LibrarySegment: String, CaseIterable, Identifiable {
    case bookmarks = "Bookmarks"
    case history = "History"

    var id: String { rawValue }
}

struct RootView: View {
    @ObservedObject var model: CompanionAppModel

    var body: some View {
        TabView {
            HomeView(model: model)
                .tabItem { Label("Home", systemImage: "house") }

            BrowserShellView(model: model)
                .tabItem { Label("Browser", systemImage: "network") }

            LibraryView(model: model)
                .tabItem { Label("Library", systemImage: "books.vertical") }

            SettingsView(model: model)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Color(hex: 0x6473FF))
    }
}

private struct HomeView: View {
    @ObservedObject var model: CompanionAppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Search or enter address", text: $model.addressInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.go)
                        .onSubmit(model.openAddressInput)

                    Button("Open in new tab", action: model.openAddressInput)
                        .buttonStyle(.borderedProminent)
                }

                Section("Spaces") {
                    if model.state.workspaces.isEmpty {
                        ContentUnavailableView("No spaces yet", systemImage: "square.grid.2x2")
                    } else {
                        ForEach(model.state.workspaces) { workspace in
                            Button {
                                model.selectWorkspace(workspace.id)
                            } label: {
                                HStack {
                                    Label(workspace.name, systemImage: workspace.icon)
                                    Spacer()
                                    if workspace.id == model.state.selectedWorkspaceID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .accessibilityLabel("Switch to \(workspace.name) space")
                        }
                    }
                }

                Section("Quick Actions") {
                    Button {
                        model.open(URL(string: "https://zen-browser.app")!, title: "Zen Browser")
                    } label: {
                        Label("Open zen-browser.app", systemImage: "safari")
                    }

                    Button(action: model.bookmarkSelectedTab) {
                        Label("Bookmark current tab", systemImage: "bookmark")
                    }
                }
            }
            .navigationTitle("Zen Companion")
        }
    }
}

private struct BrowserShellView: View {
    @ObservedObject var model: CompanionAppModel
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var showTabSheet = false
    @State private var webCommand: BrowserWebView.Command?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if model.selectedTab == nil {
                    ContentUnavailableView("No tabs open", systemImage: "square.on.square")
                } else {
                    BrowserWebView(
                        url: Binding(
                            get: { model.selectedTab?.url },
                            set: { _ in }
                        ),
                        command: $webCommand,
                        onNavigationStateChange: { back, forward in
                            canGoBack = back
                            canGoForward = forward
                        },
                        onPageMetadataChange: { url, title in
                            model.recordPageVisit(url: url, title: title)
                        }
                    )
                    .accessibilityLabel("Browser content")
                }

                Divider()

                HStack(spacing: 16) {
                    Button {
                        webCommand = .back
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!canGoBack)
                    .accessibilityLabel("Go back")

                    Button {
                        webCommand = .forward
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!canGoForward)
                    .accessibilityLabel("Go forward")

                    Button {
                        webCommand = .reload
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Reload")

                    Spacer()

                    Button(action: model.bookmarkSelectedTab) {
                        Image(systemName: "bookmark")
                    }
                    .accessibilityLabel("Bookmark current tab")

                    Button {
                        showTabSheet = true
                    } label: {
                        Label("Tabs", systemImage: "square.on.square")
                    }
                    .accessibilityLabel("Open tab list")
                }
                .padding()
                .background(.thinMaterial)
            }
            .navigationTitle(model.selectedWorkspace?.name ?? "Browser")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showTabSheet) {
                TabsView(model: model)
            }
        }
    }
}

private struct TabsView: View {
    @ObservedObject var model: CompanionAppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.selectedWorkspace?.tabs ?? []) { tab in
                    HStack {
                        Button {
                            model.selectTab(tab.id)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tab.title).font(.headline)
                                Text(tab.url.absoluteString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Button {
                            model.closeTab(tab.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close tab")
                    }
                }
            }
            .navigationTitle("Tabs")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct LibraryView: View {
    @ObservedObject var model: CompanionAppModel
    @State private var segment: LibrarySegment = .bookmarks

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Library section", selection: $segment) {
                    ForEach(LibrarySegment.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                List {
                    switch segment {
                    case .bookmarks:
                        if model.state.bookmarks.isEmpty {
                            ContentUnavailableView("No bookmarks yet", systemImage: "bookmark")
                        } else {
                            ForEach(model.state.bookmarks) { bookmark in
                                Button {
                                    model.open(bookmark.url, title: bookmark.title)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(bookmark.title)
                                        Text(bookmark.url.absoluteString)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    case .history:
                        if model.state.history.isEmpty {
                            ContentUnavailableView("No history yet", systemImage: "clock")
                        } else {
                            ForEach(model.state.history) { item in
                                Button {
                                    model.open(item.url, title: item.title)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(item.title)
                                        Text(item.url.absoluteString)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Library")
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var model: CompanionAppModel

    private var statusText: String {
        switch model.syncStatus {
        case .idle:
            return "Idle"
        case .syncing:
            return "Syncing…"
        case .offline:
            return "Offline"
        case .failed(let message, _):
            return "Error: \(message)"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account & Sync") {
                    HStack {
                        Label("Status", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        Text(statusText)
                            .foregroundStyle(colorForStatus)
                    }

                    if let lastSynced = model.syncStatus.lastSynced {
                        HStack {
                            Text("Last synced")
                            Spacer()
                            Text(lastSynced.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if case .syncing = model.syncStatus {
                        ProgressView().frame(maxWidth: .infinity)
                    }

                    Button("Sync now") {
                        Task { await model.syncNow() }
                    }
                    .buttonStyle(.borderedProminent)

                    HStack {
                        Button("Normal") { model.setSyncModeNormal() }
                        Button("Offline") { model.setSyncModeOffline() }
                        Button("Error") { model.setSyncModeError() }
                    }
                    .font(.caption)
                }

                Section("Preferences") {
                    Toggle("Use dark appearance", isOn: Binding(
                        get: { model.state.preferences.usesDarkTheme },
                        set: { model.toggleDarkMode($0) }
                    ))

                    Toggle("Allow sync on cellular", isOn: Binding(
                        get: { model.state.preferences.syncOnCellular },
                        set: { model.toggleSyncOnCellular($0) }
                    ))
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var colorForStatus: Color {
        switch model.syncStatus {
        case .idle:
            return .secondary
        case .syncing:
            return .blue
        case .offline:
            return .orange
        case .failed:
            return .red
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
#endif
