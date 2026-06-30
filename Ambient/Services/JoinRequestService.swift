import Foundation

private struct CreateJoinRequestBody: Encodable, Sendable {
    let roomID: UUID
    let proximityToken: String
}

actor JoinRequestService {
    static let shared = JoinRequestService()

    private init() {}

    func createRequest(roomID: UUID, proximityToken: String) async throws -> JoinRequestDTO {
        let body = CreateJoinRequestBody(roomID: roomID, proximityToken: proximityToken)
        return try await APIClient.shared.post("/join-requests", body: body)
    }

    func approveRequest(id: UUID) async throws {
        try await APIClient.shared.post("/join-requests/\(id.uuidString)/approve", body: EmptyBody())
    }

    func declineRequest(id: UUID) async throws {
        try await APIClient.shared.post("/join-requests/\(id.uuidString)/decline", body: EmptyBody())
    }

    func myRequests() async throws -> [JoinRequestDTO] {
        try await APIClient.shared.get("/join-requests/mine")
    }
}

private struct EmptyBody: Encodable, Sendable {}
