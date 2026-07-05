import Observation
import Foundation

@Observable
@MainActor
final class RoomViewModel {
    var room: RoomDTO? = nil
    var messages: [ChatMessageDTO] = []
    var draft: String = ""
    var isLoading = false
    var errorMessage: String? = nil

    // UWB ranging state (Tier 3) — populated once the peer's discoveryToken arrives.
    var peerDistance: Float? = nil
    var peerDirection: Float? = nil

    private(set) var myUserID: UUID?
    private var streamTask: Task<Void, Never>? = nil
    private var didSendToken = false
    private var currentRoomID: UUID?
    // Guards against reconnecting after the view has gone away — without this,
    // a dropped WS (backgrounding, network hiccup) silently stops delivering the
    // peer's messages and the chat looks "stuck" after the first exchange.
    private var isActive = false

    func load(id: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        myUserID = await MainActor.run {
            UserDefaults.standard.string(forKey: kUserIDKey).flatMap { UUID(uuidString: $0) }
        }

        currentRoomID = id
        isActive = true

        do {
            room = try await RoomService.shared.fetchRoom(id: id)
            messages = try await RoomService.shared.fetchMessages(roomID: id)
            await connect(roomID: id)
            await startUWB(peerID: room?.peerUserID)
        } catch {
            errorMessage = "Failed to load chat."
        }
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let id = room?.id else { return }
        draft = ""
        do {
            // Server also broadcasts over WS; the incoming frame is de-duplicated by id.
            let msg = try await RoomService.shared.sendMessage(roomID: id, message: text)
            appendUnique(msg)
        } catch {
            errorMessage = "Message failed to send."
        }
    }

    func cleanup() {
        isActive = false
        streamTask?.cancel(); streamTask = nil
        Task {
            await RoomService.shared.disconnect()
            await MainActor.run { NearbyInteractionService.shared.stop() }
        }
    }

    // MARK: - UWB (Tier 3)

    private func startUWB(peerID: UUID?) async {
        guard let peerID else { return }
        let ni = NearbyInteractionService.shared
        ni.onNIUpdate = { [weak self] pid, dist, dir, _ in
            guard pid == peerID else { return }
            Task { @MainActor in
                self?.peerDistance = dist
                self?.peerDirection = dir
            }
        }
        ni.onNIRemove = { [weak self] pid in
            guard pid == peerID else { return }
            Task { @MainActor in
                self?.peerDistance = nil
                self?.peerDirection = nil
            }
        }
        // If the token arrives after our first attempt, re-send it over the room WS.
        ni.onTokenReady = { [weak self] in
            Task { await self?.sendOwnToken() }
        }
        if let token = await ni.prepare() {
            _ = token
            await sendOwnToken()
        }
    }

    private func sendOwnToken() async {
        guard !didSendToken else { return }
        let base64 = await MainActor.run {
            NearbyInteractionService.shared.ownToken
                .flatMap { NearbyInteractionService.encode($0) }
        }
        guard let base64 else { return }
        didSendToken = true
        await RoomService.shared.sendDiscoveryToken(base64)
    }

    // MARK: - WebSocket

    private func connect(roomID: UUID) async {
        do {
            let stream = try await RoomService.shared.connectToRoom(id: roomID)
            streamTask = Task { @MainActor [weak self] in
                for await message in stream {
                    await self?.handle(message)
                }
                // Stream only ends when the socket closed/errored (see RoomService.receiveLoop).
                // If the room view is still open, that's an unexpected drop — not the user
                // leaving — so reconnect instead of silently going deaf to the peer's messages.
                guard let self, self.isActive, self.currentRoomID == roomID else { return }
                try? await Task.sleep(for: .seconds(2))
                guard self.isActive, self.currentRoomID == roomID else { return }
                await self.connect(roomID: roomID)
            }
        } catch {
            // Initial connect failed — REST history already loaded; retry shortly.
            guard isActive, currentRoomID == roomID else { return }
            try? await Task.sleep(for: .seconds(2))
            guard isActive, currentRoomID == roomID else { return }
            await connect(roomID: roomID)
        }
    }

    private func handle(_ message: RoomSocketMessage) async {
        switch message.event {
        case "chatMessage":
            guard let data = message.payload.data(using: .utf8) else { return }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let msg = try? decoder.decode(ChatMessageDTO.self, from: data) {
                appendUnique(msg)
            }
        case "discoveryToken":
            guard let peerID = room?.peerUserID else { return }
            await MainActor.run {
                NearbyInteractionService.shared.startPeerSession(
                    peerUserID: peerID, tokenBase64: message.payload)
            }
        default:
            break
        }
    }

    private func appendUnique(_ msg: ChatMessageDTO) {
        guard !messages.contains(where: { $0.id == msg.id }) else { return }
        messages.append(msg)
        messages.sort { $0.timestamp < $1.timestamp }
    }
}
