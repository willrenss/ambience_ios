import Observation
import Foundation

private struct ProfilePatchBody: Encodable {
    var nickname: String?
    var hometown: String?
}

@Observable
@MainActor
final class ProfileViewModel {
    var user: UserProfile? = nil
    var isLoading: Bool = false
    var allInterests: [Interest] = []

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        user = appState.currentUser
        Task { await load() }
    }

    func load() async {
        async let profileFetch: UserProfile? = try? APIClient.shared.get("/me")
        async let interestsFetch: [Interest]? = try? APIClient.shared.get("/interests")
        let (profile, interests) = await (profileFetch, interestsFetch)
        if let profile {
            user = profile
            appState.currentUser = profile
        }
        allInterests = interests ?? []
    }

    func updateNickname(_ nickname: String) async {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? await APIClient.shared.patch("/me", body: ProfilePatchBody(nickname: trimmed))
        user?.nickname = trimmed
        appState.currentUser?.nickname = trimmed
    }

    func updateHometown(_ hometown: String) async {
        let trimmed = hometown.trimmingCharacters(in: .whitespacesAndNewlines)
        let value: String? = trimmed.isEmpty ? nil : trimmed
        try? await APIClient.shared.patch("/me", body: ProfilePatchBody(hometown: value))
        user?.hometown = value
        appState.currentUser?.hometown = value
    }

    func signOut() async {
        isLoading = true
        defer { isLoading = false }
        await AuthService.shared.signOut()
        appState.currentUser = nil
    }
}
