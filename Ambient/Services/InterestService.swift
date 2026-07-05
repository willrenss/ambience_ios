import Foundation

// /interests is unauthenticated — needed during onboarding before an account exists.
actor InterestService {
    static let shared = InterestService()
    private init() {}

    func fetchInterests() async throws -> [Interest] {
        try await APIClient.shared.get("/interests")
    }
}
