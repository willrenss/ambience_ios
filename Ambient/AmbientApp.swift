import SwiftUI

@main
struct NowiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
                // Belt-and-suspenders alongside INFOPLIST_KEY_UIUserInterfaceStyle=Light:
                // that setting locks the OS-level chrome (keyboard, alerts) to light,
                // this locks SwiftUI's own color scheme (e.g. in Xcode Previews).
                .preferredColorScheme(.light)
                .onAppear {
                    // AppDelegate sits outside the environment, so it needs a direct
                    // reference to reach shared state from notification callbacks.
                    AppDelegate.appState = appState
                }
        }
    }
}

#Preview {
    @Previewable @State var appState = AppState()

    RootView()
        .environment(appState)
        .preferredColorScheme(.light)
}
