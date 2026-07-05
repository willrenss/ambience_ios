import Foundation

private struct PingBody: Encodable, Sendable {
    let toUserID: UUID
}

actor PingService {
    static let shared = PingService()
    private init() {}

    // Send a one-directional ping. If mutual, the response carries the new roomID.
    func ping(eventID: UUID, toUserID: UUID) async throws -> PingResponse {
        try await APIClient.shared.post("/events/\(eventID.uuidString)/ping",
                                        body: PingBody(toUserID: toUserID))
    }

    // Pings this user has received for the event (never reveals reciprocation state).
    func notifications(eventID: UUID) async throws -> [PingNotificationDTO] {
        try await APIClient.shared.get("/events/\(eventID.uuidString)/notifications")
    }
}
