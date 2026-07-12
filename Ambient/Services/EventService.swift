import Foundation

private struct LocationBody: Sendable {
    let latitude: Double
    let longitude: Double
}

extension LocationBody: Encodable {
    private enum CodingKeys: CodingKey { case latitude, longitude }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(latitude, forKey: .latitude)
        try c.encode(longitude, forKey: .longitude)
    }
}

actor EventService {
    static let shared = EventService()
    private init() {}

    func fetchEvents(category: String? = nil) async throws -> [EventDTO] {
        guard let category, !category.isEmpty else {
            return try await APIClient.shared.get("/events")
        }
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "category", value: category)]
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        return try await APIClient.shared.get("/events\(query)")
    }

    func fetchEvent(id: UUID) async throws -> EventDTO {
        try await APIClient.shared.get("/events/\(id.uuidString)")
    }

    // Arm radar server-side; returns whether the user is within the 500m radius.
    func join(eventID: UUID, latitude: Double, longitude: Double) async throws -> JoinEventResponse {
        try await APIClient.shared.post("/events/\(eventID.uuidString)/join",
                                        body: LocationBody(latitude: latitude, longitude: longitude))
    }

    // Periodic keep-alive so the server can auto-disarm radar when the user leaves radius.
    func heartbeat(eventID: UUID, latitude: Double, longitude: Double) async throws -> JoinEventResponse {
        try await APIClient.shared.post("/events/\(eventID.uuidString)/heartbeat",
                                        body: LocationBody(latitude: latitude, longitude: longitude))
    }

    func leave(eventID: UUID) async throws {
        try await APIClient.shared.post("/events/\(eventID.uuidString)/leave", body: EmptyBody())
    }

    func fetchRadar(eventID: UUID) async throws -> [EventRadarUserDTO] {
        try await APIClient.shared.get("/events/\(eventID.uuidString)/radar")
    }

    func bookmark(eventID: UUID) async throws {
        try await APIClient.shared.post("/events/\(eventID.uuidString)/bookmark", body: EmptyBody())
    }

    func unbookmark(eventID: UUID) async throws {
        try await APIClient.shared.delete("/events/\(eventID.uuidString)/bookmark")
    }

    /// Dedicated endpoint for map bookmark filter — separate from the search/browse flow.
    func fetchBookmarkedEvents() async throws -> [EventDTO] {
        try await APIClient.shared.get("/events/bookmarks")
    }
}

struct EmptyBody: Sendable {}

extension EmptyBody: Encodable {
    nonisolated func encode(to encoder: any Encoder) throws {
        // Encode as `{}` — delegate to stdlib Dictionary which is not @MainActor isolated.
        try [String: String]().encode(to: encoder)
    }
}
