import Foundation

private struct CreateRoomRequest: Encodable {
    let venueID: UUID
    let proximityToken: String
}

actor RoomService {
    static let shared = RoomService()

    private var webSocketTask: URLSessionWebSocketTask?
    private var streamContinuation: AsyncStream<RoomSocketMessage>.Continuation?

    private init() {}

    func createRoom(venueID: UUID, proximityToken: String) async throws -> RoomDTO {
        let body = CreateRoomRequest(venueID: venueID, proximityToken: proximityToken)
        return try await APIClient.shared.post("/rooms", body: body)
    }

    func fetchRoomState(id: UUID) async throws -> RoomStateDTO {
        try await APIClient.shared.get("/rooms/\(id.uuidString)/state")
    }

    func leaveRoom(id: UUID) async throws {
        try await APIClient.shared.post("/rooms/\(id.uuidString)/leave", body: EmptyBody())
    }

    func dissolveRoom(id: UUID) async throws {
        try await APIClient.shared.delete("/rooms/\(id.uuidString)")
    }

    // MARK: - WebSocket

    func connectToRoom(id: UUID, token: String) async throws -> AsyncStream<RoomSocketMessage> {
        await disconnect()

        guard let url = await APIClient.shared.webSocketURL(path: "/ws/room/\(id.uuidString)") else {
            throw APIError.invalidURL
        }

        let stream = AsyncStream<RoomSocketMessage> { continuation in
            self.streamContinuation = continuation
        }

        let task = URLSession.shared.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        Task {
            await receiveLoop(task: task)
        }

        return stream
    }

    func disconnect() async {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        streamContinuation?.finish()
        streamContinuation = nil
    }

    // MARK: - Private

    private func receiveLoop(task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let msg = try? JSONDecoder().decode(RoomSocketMessage.self, from: data) {
                        streamContinuation?.yield(msg)
                    }
                case .data(let data):
                    if let msg = try? JSONDecoder().decode(RoomSocketMessage.self, from: data) {
                        streamContinuation?.yield(msg)
                    }
                @unknown default:
                    break
                }
            } catch {
                streamContinuation?.finish()
                break
            }
        }
    }
}

private struct EmptyBody: Encodable {}
