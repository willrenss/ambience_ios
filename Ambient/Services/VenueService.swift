import Foundation

actor VenueService {
    static let shared = VenueService()

    private init() {}

    func fetchVenues() async throws -> [VenueDTO] {
        try await APIClient.shared.get("/venues")
    }

    func fetchVenue(id: UUID) async throws -> VenueDTO {
        try await APIClient.shared.get("/venues/\(id.uuidString)")
    }

    func fetchNearbyVenues(latitude: Double, longitude: Double, radiusKm: Double) async throws -> [VenueDTO] {
        try await APIClient.shared.get(
            "/venues/nearby?lat=\(latitude)&lon=\(longitude)&radius=\(radiusKm)"
        )
    }
}
