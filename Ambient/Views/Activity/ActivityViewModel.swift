import Observation
import Foundation

@Observable
@MainActor
final class ActivityViewModel {
    var joinRequests: [JoinRequestDTO] = []
    var matches: [MatchDTO] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil

    func loadActivity() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let requests = JoinRequestService.shared.myRequests()
            async let fetchedMatches = fetchMatches()
            joinRequests = try await requests
            matches = (try? await fetchedMatches) ?? []
        } catch {
            errorMessage = "Failed to load activity."
        }
    }

    private func fetchMatches() async throws -> [MatchDTO] {
        try await APIClient.shared.get("/matches/mine")
    }
}
