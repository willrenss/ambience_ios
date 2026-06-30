import Observation
import Foundation

@Observable
@MainActor
final class VenuesViewModel {
    var venues: [VenueDTO] = []
    var searchText: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil

    var filteredVenues: [VenueDTO] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return venues
        }
        return venues.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.address.localizedCaseInsensitiveContains(searchText)
        }
    }

    func loadVenues() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            venues = try await VenueService.shared.fetchVenues()
        } catch {
            errorMessage = "Failed to load venues."
        }
    }
}
