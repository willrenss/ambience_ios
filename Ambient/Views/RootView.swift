import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
<<<<<<< HEAD

    var body: some View {
        if appState.isAuthenticated {
            MainTabView()
        } else {
            LoginView()
=======
    // Starts true so we never flash the onboarding wizard before we've had a
    // chance to check for a stored session — only the account-creation path
    // should ever be able to show OnboardingView.
    @State private var isRestoringSession = true

    var body: some View {
        Group {
            if isRestoringSession {
                Color.peach.opacity(0.35).ignoresSafeArea()
                    .overlay { ProgressView() }
            } else if !appState.isAuthenticated {
                OnboardingView()
            } else if !appState.hasSeenPermissionsPriming {
                PermissionsPrimingView()
            } else {
                MainTabView()
            }
        }
        .task {
            appState.currentUser = await AuthService.shared.restoreSession()
            isRestoringSession = false
>>>>>>> c5f4022 (Iniatial Commit)
        }
    }
}
