import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var isRestoringSession = true
    @State private var showSplash = false

    var body: some View {
        Group {
            if isRestoringSession {
                Color.peach.opacity(0.35).ignoresSafeArea()
                    .overlay { ProgressView() }
            } else if showSplash {
                OnboardingSplashView()
                    .transition(.opacity)
            } else if !appState.hasSeenWalkthrough {
                WalkthroughView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        appState.hasSeenWalkthrough = true
                    }
                }
                .transition(.opacity)
            } else if !appState.isAuthenticated {
                OnboardingView()
            } else if !appState.hasSeenPermissionsPriming {
                PermissionsPrimingView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showSplash)
        .animation(.easeInOut(duration: 0.35), value: appState.hasSeenWalkthrough)
        .task {
            appState.currentUser = await AuthService.shared.restoreSession()
            isRestoringSession = false

            // Show splash only on very first launch (walkthrough not yet seen).
            if !appState.hasSeenWalkthrough {
                showSplash = true
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
            }
        }
        .onChange(of: appState.devTriggerSplash) { _, triggered in
            guard triggered else { return }
            Task {
                // Splash covers the screen first, so signing out and resetting the
                // onboarding flags underneath never flashes the wrong screen through.
                withAnimation(.easeInOut(duration: 0.35)) { showSplash = true }
                await AuthService.shared.signOut()
                appState.currentUser = nil
                appState.hasSeenWalkthrough = false
                appState.hasSeenPermissionsPriming = false
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
                appState.devTriggerSplash = false
            }
        }
    }
}
