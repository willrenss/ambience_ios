import Foundation

private struct LoginRequest: Encodable, Sendable {
    let name: String
}

private struct LoginResponse: Decodable, Sendable {
    let token: String
    let userID: UUID
    let displayName: String
}

actor AuthService {
    static let shared = AuthService()

    private let tokenKey        = "ambsocial_token"
    private let userIDKey       = "ambsocial_user_id"
    private let displayNameKey  = "ambsocial_display_name"

    private init() {}

    func login(name: String) async throws -> UserProfile {
        let body = LoginRequest(name: name)
        let response: LoginResponse = try await APIClient.shared.post("/auth/login", body: body)

        await APIClient.shared.setToken(response.token)
        KeychainHelper.shared.save(response.token, forKey: tokenKey)

        let profile = UserProfile(id: response.userID, displayName: response.displayName)
        await persistProfile(profile)
        return profile
    }

    func signOut() async {
        await APIClient.shared.clearToken()
        KeychainHelper.shared.delete(forKey: tokenKey)
        await MainActor.run {
            UserDefaults.standard.removeObject(forKey: userIDKey)
            UserDefaults.standard.removeObject(forKey: displayNameKey)
        }
    }

    func restoreSession() async -> UserProfile? {
        guard let token = KeychainHelper.shared.load(forKey: tokenKey) else { return nil }
        let (idString, displayName) = await MainActor.run {
            (UserDefaults.standard.string(forKey: userIDKey),
             UserDefaults.standard.string(forKey: displayNameKey))
        }
        guard let idString,
              let userID = UUID(uuidString: idString),
              let displayName
        else { return nil }
        await APIClient.shared.setToken(token)
        return UserProfile(id: userID, displayName: displayName)
    }

    private func persistProfile(_ profile: UserProfile) async {
        await MainActor.run {
            UserDefaults.standard.set(profile.id.uuidString, forKey: userIDKey)
            UserDefaults.standard.set(profile.displayName, forKey: displayNameKey)
        }
    }
}
