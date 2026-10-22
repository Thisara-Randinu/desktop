#if canImport(SwiftUI) && canImport(WebKit)
import SwiftUI

@main
struct ZenCompanionApp: App {
    @StateObject private var model = CompanionAppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .preferredColorScheme(model.state.preferences.usesDarkTheme ? .dark : nil)
        }
    }
}
#else
@main
struct ZenCompanionApp {
    static func main() {
        print("ZenCompanionApp is available when built for iOS in Xcode.")
    }
}
#endif
