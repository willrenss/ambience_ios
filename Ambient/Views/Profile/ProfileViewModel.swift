import Observation
import Foundation

@Observable
@MainActor
final class ProfileViewModel {
    var user: UserProfile? = nil
    var isLoading: Bool = false

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        user = appState.currentUser
    }

    func signOut() async {
        isLoading = true
        defer { isLoading = false }
        await AuthService.shared.signOut()
        appState.currentUser = nil
    }
}
