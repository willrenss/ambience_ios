import Foundation

// "My matches" and "my active rooms" are the same list — a Room exists only from a mutual match.
actor MatchService {
    static let shared = MatchService()
    private init() {}

    func fetchMatches() async throws -> [RoomDTO] {
        try await APIClient.shared.get("/matches")
    }
}
