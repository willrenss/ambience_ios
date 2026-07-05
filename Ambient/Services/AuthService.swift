import Foundation

<<<<<<< HEAD
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
=======
private struct SignupRequest: Encodable, Sendable {
    let nickname: String
    let birthdate: Date
    let hometown: String?
    let deviceToken: String?
    let interestIDs: [UUID]
}

private struct LoginRequest: Encodable, Sendable {
    let userID: UUID
    let secretKey: String
}

// Keychain / UserDefaults keys — shared with AppIntents which read the token directly.
let kAuthTokenKey  = "ambsocial_token"
let kSecretKeyKey  = "ambsocial_secret_key"
let kUserIDKey     = "ambsocial_user_id"
let kNicknameKey   = "ambsocial_nickname"

actor AuthService {
    static let shared = AuthService()

    private init() {}

    func signup(nickname: String,
                birthdate: Date,
                hometown: String?,
                interestIDs: [UUID]) async throws -> UserProfile {
        let body = SignupRequest(
            nickname: nickname,
            birthdate: birthdate,
            hometown: hometown,
            deviceToken: nil,
            interestIDs: interestIDs
        )
        let response: AuthResponse = try await APIClient.shared.post("/auth/signup", body: body)
        await applySession(response)
        // secretKey is returned only at signup — persisting it is the only account recovery path.
        if let secret = response.secretKey {
            KeychainHelper.shared.save(secret, forKey: kSecretKeyKey)
        }
        return UserProfile(id: response.userID, nickname: response.nickname)
    }

    func login(userID: UUID, secretKey: String) async throws -> UserProfile {
        let body = LoginRequest(userID: userID, secretKey: secretKey)
        let response: AuthResponse = try await APIClient.shared.post("/auth/login", body: body)
        await applySession(response)
        return UserProfile(id: response.userID, nickname: response.nickname)
>>>>>>> c5f4022 (Iniatial Commit)
    }

    func signOut() async {
        await APIClient.shared.clearToken()
<<<<<<< HEAD
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
=======
        KeychainHelper.shared.delete(forKey: kAuthTokenKey)
        KeychainHelper.shared.delete(forKey: kSecretKeyKey)
        await MainActor.run {
            UserDefaults.standard.removeObject(forKey: kUserIDKey)
            UserDefaults.standard.removeObject(forKey: kNicknameKey)
        }
    }

    // Restore a live session from the stored JWT, or re-login via the stored secretKey.
    func restoreSession() async -> UserProfile? {
        let (idString, nickname) = await MainActor.run {
            (UserDefaults.standard.string(forKey: kUserIDKey),
             UserDefaults.standard.string(forKey: kNicknameKey))
        }
        guard let idString, let userID = UUID(uuidString: idString) else { return nil }

        // Re-login via the stored secretKey is the only way to confirm the
        // account still exists server-side (e.g. it can be gone after a dev
        // DB reset while this device still has an old cached session).
        if let secret = KeychainHelper.shared.load(forKey: kSecretKeyKey) {
            if let refreshed = try? await login(userID: userID, secretKey: secret) {
                return refreshed
            }
            // Login explicitly failed — the account no longer exists (or the
            // secret is wrong). Previously this fell through to fabricate a
            // UserProfile from cached UserDefaults data, silently "logging
            // in" a phantom account whose JWT didn't resolve to any real
            // row — every authenticated call after that would fail. Clear
            // the stale session instead so the user goes back to onboarding.
            await signOut()
            return nil
        }

        // No secret stored (shouldn't normally happen) — fall back to the
        // cached token only if present.
        if let token = KeychainHelper.shared.load(forKey: kAuthTokenKey) {
            await APIClient.shared.setToken(token)
            if let nickname { return UserProfile(id: userID, nickname: nickname) }
        }
        return nil
    }

    private func applySession(_ response: AuthResponse) async {
        await APIClient.shared.setToken(response.token)
        KeychainHelper.shared.save(response.token, forKey: kAuthTokenKey)
        await MainActor.run {
            UserDefaults.standard.set(response.userID.uuidString, forKey: kUserIDKey)
            UserDefaults.standard.set(response.nickname, forKey: kNicknameKey)
>>>>>>> c5f4022 (Iniatial Commit)
        }
    }
}
