import Observation
import Foundation

private struct ProfilePatchBody: Encodable {
    var nickname: String?
    var hometown: String?
    var birthdate: Date?
    var interestIDs: [UUID]?
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

    // There's no separate stored "age" — picking an Age Group just sets a
    // birthdate matching that group's representative midpoint age.
    func updateAgeGroup(_ group: OnboardingAgeGroup) async {
        guard let newBirthdate = Calendar.current.date(byAdding: .year, value: -group.midAge, to: .now) else { return }
        try? await APIClient.shared.patch("/me", body: ProfilePatchBody(birthdate: newBirthdate))
        user?.birthdate = newBirthdate
        user?.age = group.midAge
        appState.currentUser?.birthdate = newBirthdate
        appState.currentUser?.age = group.midAge
    }

    // Replaces the user's full interest set, matching the picker's Done-saves-whatever's-checked UX.
    func updateInterests(_ names: Set<String>) async {
        let ids = allInterests.filter { names.contains($0.name) }.map(\.id)
        try? await APIClient.shared.patch("/me", body: ProfilePatchBody(interestIDs: ids))
        let updated = allInterests.filter { ids.contains($0.id) }.map(\.name)
        user?.interests = updated
        appState.currentUser?.interests = updated
    }

    func uploadPhoto(_ imageData: Data) async {
        do {
            let updated: UserProfile = try await APIClient.shared.uploadFile(
                "/me/photo", fieldName: "photo", filename: "profile.jpg",
                mimeType: "image/jpeg", data: imageData
            )
            user = updated
            appState.currentUser = updated
        } catch {
            // Non-fatal — the picker UI just won't show a new image; existing photo
            // (or the initials placeholder) stays in place.
        }
    }

    func signOut() async {
        isLoading = true
        defer { isLoading = false }
        await AuthService.shared.signOut()
        appState.currentUser = nil
    }
}
