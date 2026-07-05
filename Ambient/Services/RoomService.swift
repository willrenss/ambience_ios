import Foundation

<<<<<<< HEAD
private struct CreateRoomRequest: Encodable {
    let venueID: UUID
    let proximityToken: String
=======
private struct SendMessageBody: Encodable, Sendable {
    let message: String
>>>>>>> c5f4022 (Iniatial Commit)
}

actor RoomService {
    static let shared = RoomService()

    private var webSocketTask: URLSessionWebSocketTask?
    private var streamContinuation: AsyncStream<RoomSocketMessage>.Continuation?
<<<<<<< HEAD

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
=======
    private var receiveTask: Task<Void, Never>?
    // Bumped on every connect/disconnect so a stale receiveLoop from a previous
    // connection can never finish/touch a newer generation's continuation.
    private var generation = 0

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private init() {}

    // MARK: - REST

    func fetchRoom(id: UUID) async throws -> RoomDTO {
        try await APIClient.shared.get("/rooms/\(id.uuidString)")
    }

    func fetchMessages(roomID: UUID) async throws -> [ChatMessageDTO] {
        try await APIClient.shared.get("/rooms/\(roomID.uuidString)/messages")
    }

    @discardableResult
    func sendMessage(roomID: UUID, message: String) async throws -> ChatMessageDTO {
        try await APIClient.shared.post("/rooms/\(roomID.uuidString)/messages",
                                        body: SendMessageBody(message: message))
>>>>>>> c5f4022 (Iniatial Commit)
    }

    // MARK: - WebSocket

<<<<<<< HEAD
    func connectToRoom(id: UUID, token: String) async throws -> AsyncStream<RoomSocketMessage> {
=======
    func connectToRoom(id: UUID) async throws -> AsyncStream<RoomSocketMessage> {
>>>>>>> c5f4022 (Iniatial Commit)
        await disconnect()

        guard let url = await APIClient.shared.webSocketURL(path: "/ws/room/\(id.uuidString)") else {
            throw APIError.invalidURL
        }

<<<<<<< HEAD
        let stream = AsyncStream<RoomSocketMessage> { continuation in
            self.streamContinuation = continuation
        }
=======
        generation += 1
        let myGeneration = generation

        var capturedContinuation: AsyncStream<RoomSocketMessage>.Continuation?
        let stream = AsyncStream<RoomSocketMessage> { continuation in
            capturedContinuation = continuation
        }
        streamContinuation = capturedContinuation
>>>>>>> c5f4022 (Iniatial Commit)

        let task = URLSession.shared.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
<<<<<<< HEAD

        Task {
            await receiveLoop(task: task)
        }

        return stream
    }

    func disconnect() async {
=======
        receiveTask = Task { await receiveLoop(task: task, continuation: capturedContinuation, generation: myGeneration) }
        return stream
    }

    // Send our own NIDiscoveryToken frame; the server relays it to the other participant only.
    func sendDiscoveryToken(_ base64: String) async {
        await send(RoomSocketMessage(event: "discoveryToken", payload: base64))
    }

    func disconnect() async {
        generation += 1  // invalidate any in-flight receiveLoop from the connection being torn down
        receiveTask?.cancel(); receiveTask = nil
>>>>>>> c5f4022 (Iniatial Commit)
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        streamContinuation?.finish()
        streamContinuation = nil
    }

    // MARK: - Private

<<<<<<< HEAD
    private func receiveLoop(task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
=======
    private func send(_ message: RoomSocketMessage) async {
        guard let task = webSocketTask,
              let data = try? encoder.encode(message),
              let text = String(data: data, encoding: .utf8)
        else { return }
        try? await task.send(.string(text))
    }

    // Takes its continuation and generation by value so a superseded connection's
    // loop can never yield/finish a newer connection's stream (see `generation`).
    private func receiveLoop(
        task: URLSessionWebSocketTask,
        continuation: AsyncStream<RoomSocketMessage>.Continuation?,
        generation myGeneration: Int
    ) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                guard generation == myGeneration else { return }
>>>>>>> c5f4022 (Iniatial Commit)
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let msg = try? JSONDecoder().decode(RoomSocketMessage.self, from: data) {
<<<<<<< HEAD
                        streamContinuation?.yield(msg)
                    }
                case .data(let data):
                    if let msg = try? JSONDecoder().decode(RoomSocketMessage.self, from: data) {
                        streamContinuation?.yield(msg)
=======
                        continuation?.yield(msg)
                    }
                case .data(let data):
                    if let msg = try? JSONDecoder().decode(RoomSocketMessage.self, from: data) {
                        continuation?.yield(msg)
>>>>>>> c5f4022 (Iniatial Commit)
                    }
                @unknown default:
                    break
                }
            } catch {
<<<<<<< HEAD
                streamContinuation?.finish()
=======
                if generation == myGeneration { continuation?.finish() }
>>>>>>> c5f4022 (Iniatial Commit)
                break
            }
        }
    }
}
<<<<<<< HEAD

private struct EmptyBody: Encodable {}
=======
>>>>>>> c5f4022 (Iniatial Commit)
