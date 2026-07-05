import SwiftUI

@main
struct AmbientApp: App {
    @State private var appState = AppState()

    init() {
        // Sync APIClient with the user's saved URL at launch.
        // Task { @MainActor in } guarantees UserDefaults access runs on MainActor (iOS 18 SDK).
        Task { @MainActor in
            await APIClient.shared.updateBaseURL(ServerConfig.currentURL)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
<<<<<<< HEAD
=======
                // Belt-and-suspenders alongside INFOPLIST_KEY_UIUserInterfaceStyle=Light:
                // that setting locks the OS-level chrome (keyboard, alerts) to light,
                // this locks SwiftUI's own color scheme (e.g. in Xcode Previews).
                .preferredColorScheme(.light)
>>>>>>> c5f4022 (Iniatial Commit)
        }
    }
}
