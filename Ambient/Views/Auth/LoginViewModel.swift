import Observation
import Foundation

@Observable
@MainActor
final class LoginViewModel {
    var name: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func login() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter your name."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let profile = try await AuthService.shared.login(name: trimmed)
            appState.currentUser = profile
        } catch {
            errorMessage = "Could not connect. Make sure the server is running."
        }
    }
}
