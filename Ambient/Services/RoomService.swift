import Foundation

private struct SendMessageBody: Sendable {
    let message: String
}

extension SendMessageBody: Encodable {
    private enum CodingKeys: CodingKey { case message }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(message, forKey: .message)
    }
}

actor RoomService {
    static let shared = RoomService()

    private var webSocketTask: URLSessionWebSocketTask?
    private var streamContinuation: AsyncStream<RoomSocketMessage>.Continuation?
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
    }

    // MARK: - WebSocket

    func connectToRoom(id: UUID) async throws -> AsyncStream<RoomSocketMessage> {
        await disconnect()

        guard let url = await APIClient.shared.webSocketURL(path: "/ws/room/\(id.uuidString)") else {
            throw APIError.invalidURL
        }

        generation += 1
        let myGeneration = generation

        var capturedContinuation: AsyncStream<RoomSocketMessage>.Continuation?
        let stream = AsyncStream<RoomSocketMessage> { continuation in
            capturedContinuation = continuation
        }
        streamContinuation = capturedContinuation

        let task = URLSession.shared.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
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
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        streamContinuation?.finish()
        streamContinuation = nil
    }

    // MARK: - Private

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
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let msg = try? JSONDecoder().decode(RoomSocketMessage.self, from: data) {
                        continuation?.yield(msg)
                    }
                case .data(let data):
                    if let msg = try? JSONDecoder().decode(RoomSocketMessage.self, from: data) {
                        continuation?.yield(msg)
                    }
                @unknown default:
                    break
                }
            } catch {
                if generation == myGeneration { continuation?.finish() }
                break
            }
        }
    }
}
