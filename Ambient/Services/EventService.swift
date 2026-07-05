import Foundation

private struct LocationBody: Encodable, Sendable {
    let latitude: Double
    let longitude: Double
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
}

struct EmptyBody: Encodable, Sendable {}
