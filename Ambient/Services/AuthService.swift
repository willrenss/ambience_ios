import Foundation

// MARK: - Request types

// Explicit nonisolated Encodable avoids the @MainActor synthesis that
// SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor would otherwise apply, allowing
// these types to be encoded inside any actor (e.g. APIClient).

private struct SignupRequest: Sendable {
    let nickname: String
    let birthdate: Date
    let hometown: String?
    let deviceToken: String?
    let interestIDs: [UUID]
}

extension SignupRequest: Encodable {
    private enum CodingKeys: String, CodingKey {
        case nickname, birthdate, hometown, deviceToken, interestIDs
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(nickname, forKey: .nickname)
        try c.encode(birthdate, forKey: .birthdate)
        try c.encodeIfPresent(hometown, forKey: .hometown)
        try c.encodeIfPresent(deviceToken, forKey: .deviceToken)
        try c.encode(interestIDs, forKey: .interestIDs)
    }
}

private struct LoginRequest: Sendable {
    let userID: UUID
    let secretKey: String
}

extension LoginRequest: Encodable {
    private enum CodingKeys: String, CodingKey { case userID, secretKey }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(userID, forKey: .userID)
        try c.encode(secretKey, forKey: .secretKey)
    }
}

// MARK: - Keychain keys

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
    }

    func signOut() async {
        await APIClient.shared.clearToken()
        KeychainHelper.shared.delete(forKey: kAuthTokenKey)
        KeychainHelper.shared.delete(forKey: kSecretKeyKey)
        await MainActor.run {
            UserDefaults.standard.removeObject(forKey: kUserIDKey)
            UserDefaults.standard.removeObject(forKey: kNicknameKey)
        }
    }

    // Restore session from cache instantly — no network call on startup.
    // The token will be validated naturally on the first authenticated API call;
    // if it's expired or the account is gone the call returns 401 and the app
    // can sign the user out then.
    func restoreSession() async -> UserProfile? {
        let (idString, nickname) = await MainActor.run {
            (UserDefaults.standard.string(forKey: kUserIDKey),
             UserDefaults.standard.string(forKey: kNicknameKey))
        }
        guard let idString,
              let userID = UUID(uuidString: idString),
              let nickname else { return nil }

        if let token = KeychainHelper.shared.load(forKey: kAuthTokenKey) {
            await APIClient.shared.setToken(token)
            return UserProfile(id: userID, nickname: nickname)
        }

        // No token cached — try re-login with the secret key (e.g. fresh install
        // with iCloud keychain sync but no JWT yet).
        if let secret = KeychainHelper.shared.load(forKey: kSecretKeyKey) {
            if let profile = try? await login(userID: userID, secretKey: secret) {
                return profile
            }
            await signOut()
        }
        return nil
    }

    private func applySession(_ response: AuthResponse) async {
        await APIClient.shared.setToken(response.token)
        KeychainHelper.shared.save(response.token, forKey: kAuthTokenKey)
        await MainActor.run {
            UserDefaults.standard.set(response.userID.uuidString, forKey: kUserIDKey)
            UserDefaults.standard.set(response.nickname, forKey: kNicknameKey)
        }
    }
}
