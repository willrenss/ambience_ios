import Observation
import Foundation
import NearbyInteraction

@Observable
@MainActor
final class RoomViewModel {
    var room: RoomDTO? = nil
    var messages: [ChatMessageDTO] = []
    var draft: String = ""
    var isLoading = false
    var errorMessage: String? = nil

    // WebSocket + UWB state
    var isWSConnected: Bool = false    // true once the room WS handshake succeeds
    var peerDistance: Float? = nil
    var isUWBSearching: Bool = false   // true after token generated, before first ranging update
    var isInitiator: Bool = false      // current user was first pinger → UWB guest
    // true when prepare() exhausted retries and token still nil — show Settings button in strip
    var uwbPermissionPending: Bool = false

    private(set) var myUserID: UUID?
    private var streamTask: Task<Void, Never>? = nil
    private var retryTask: Task<Void, Never>? = nil
    private var didSendToken = false
    private var currentRoomID: UUID?
    // Buffers the peer's discovery token if it arrives before our NI session is ready
    private var pendingPeerToken: String? = nil
    // Guards against reconnecting after the view has gone away — without this,
    // a dropped WS (backgrounding, network hiccup) silently stops delivering the
    // peer's messages and the chat looks "stuck" after the first exchange.
    private var isActive = false
    // Local peer-to-peer token exchange (like UWBDemo) — faster and more reliable than
    // routing tokens through the WebSocket server, and works without internet.
    private var mcExchange: UWBTokenExchangeService?

    func load(id: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        myUserID = await MainActor.run {
            UserDefaults.standard.string(forKey: kUserIDKey).flatMap { UUID(uuidString: $0) }
        }

        currentRoomID = id
        isActive = true
        uwbLog("━━━ Room dibuka: \(id.uuidString.prefix(8)) ━━━")

        do {
            room = try await RoomService.shared.fetchRoom(id: id)
            isInitiator = room?.isInitiator ?? false
            messages = try await RoomService.shared.fetchMessages(roomID: id)

            let peerID = room?.peerUserID
            // Start UWB concurrently with the WS connect — NISession must be created
            // independently so the Nearby Interactions permission dialog appears even
            // if the WebSocket is slow or keeps retrying. Token exchange completes
            // via the peerConnected / resendOwnToken flow once both sides are up.
            Task { @MainActor [weak self] in
                await self?.startUWB(peerID: peerID)
            }
            await connect(roomID: id)
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
        isWSConnected = false
        didSendToken = false
        pendingPeerToken = nil
        streamTask?.cancel(); streamTask = nil
        retryTask?.cancel(); retryTask = nil
        mcExchange?.stop(); mcExchange = nil
        Task {
            await RoomService.shared.disconnect()
            await MainActor.run { NearbyInteractionService.shared.stop() }
        }
    }

    // MARK: - UWB (Tier 3)

    private func startUWB(peerID: UUID?) async {
        guard let peerID, let roomID = currentRoomID else {
            uwbLog("⚠️ startUWB: peerID=\(peerID?.uuidString ?? "nil") roomID=\(currentRoomID?.uuidString ?? "nil") — abort")
            return
        }
        uwbLog("🚀 startUWB: peer=\(peerID.uuidString.prefix(8))")
        let ni = NearbyInteractionService.shared
        // Force a fresh session when the user explicitly opens a chat room.
        // This creates NISession in a foreground user-interaction context, which
        // is more reliable for triggering the iOS permission dialog than the
        // background .task {} call in MainTabView.
        if ni.ownToken == nil {
            ni.retryTokenGeneration()
        }

        // Start MC-based token exchange in parallel — same approach as UWBDemo.
        let mc = UWBTokenExchangeService()
        mc.start(roomID: roomID)
        mc.onPeerTokenReceived = { [weak self] tokenBase64 in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.uwbLog("📥 Peer token via MC — memanggil startPeerSession")
                self.pendingPeerToken = tokenBase64
                NearbyInteractionService.shared.startPeerSession(
                    peerUserID: peerID, tokenBase64: tokenBase64)
            }
        }
        mcExchange = mc

        ni.onNIUpdate = { [weak self] pid, dist, _, _ in
            guard pid == peerID else { return }
            Task { @MainActor [weak self] in
                self?.peerDistance = dist
                self?.isUWBSearching = false
            }
        }
        ni.onNIRemove = { [weak self] pid in
            guard pid == peerID else { return }
            Task { @MainActor [weak self] in
                self?.peerDistance = nil
            }
        }
        ni.onTokenReady = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.retryTask?.cancel()
                self.retryTask = nil
                self.uwbPermissionPending = false
                self.isUWBSearching = true
                await self.sendOwnToken()
                await self.applyPendingPeerToken()
            }
        }
        if let _ = await ni.prepare() {
            uwbLog("✅ prepare() sukses — token ready")
            isUWBSearching = true
            await sendOwnToken()
            await applyPendingPeerToken()
        } else if ni.isPermissionDenied {
            uwbLog("❌ Permission NI denied — enable di Settings > Privacy > Nearby Interactions")
            isUWBSearching = false
        } else if ni.isUWBEnabled {
            // prepare() timed out (18s) tapi session masih hidup — permission belum granted.
            // Tampilkan tombol "Buka Settings" dan retry setiap 15s di background.
            uwbLog("⏳ prepare() timeout — tampilkan tombol Settings, retry setiap 15s...")
            isUWBSearching = true
            uwbPermissionPending = true
            retryTask = Task { @MainActor [weak self] in
                await self?.retryUWBLoop()
            }
        }
    }

    // Retries NISession creation every 15s until token generates or room closes.
    // Covers the case where the iOS permission dialog appeared but wasn't responded to,
    // or the NI framework had a transient failure. onTokenReady handles success.
    private func retryUWBLoop() async {
        let ni = NearbyInteractionService.shared
        var attempt = 1
        while isActive, !ni.isPermissionDenied, ni.ownToken == nil {
            try? await Task.sleep(for: .seconds(15))
            guard isActive, !ni.isPermissionDenied, ni.ownToken == nil else { break }
            uwbLog("🔄 Retry \(attempt): buat ulang NISession (permission belum granted?)")
            ni.retryTokenGeneration()
            attempt += 1
        }
    }

    private func sendOwnToken() async {
        guard !didSendToken else { return }
        let base64 = await MainActor.run {
            NearbyInteractionService.shared.ownToken
                .flatMap { NearbyInteractionService.encode($0) }
        }
        guard let base64 else {
            uwbLog("⚠️ sendOwnToken: ownToken nil, skip")
            return
        }
        didSendToken = true
        uwbLog("📤 Own token dikirim via MC + WebSocket")
        mcExchange?.sendToken(base64)
        await RoomService.shared.sendDiscoveryToken(base64)
    }

    // MARK: - WebSocket

    private func connect(roomID: UUID) async {
        do {
            let stream = try await RoomService.shared.connectToRoom(id: roomID)
            isWSConnected = true
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
            uwbLog("📥 Peer token via WebSocket — memanggil startPeerSession")
            pendingPeerToken = message.payload
            await MainActor.run {
                NearbyInteractionService.shared.startPeerSession(
                    peerUserID: peerID, tokenBase64: message.payload)
            }
        case "peerConnected":
            uwbLog("🔗 peerConnected event — resend token via WebSocket")
            await resendOwnToken()
        default:
            break
        }
    }

    private func resendOwnToken() async {
        let base64 = await MainActor.run {
            NearbyInteractionService.shared.ownToken
                .flatMap { NearbyInteractionService.encode($0) }
        }
        guard let base64 else { return }
        await RoomService.shared.sendDiscoveryToken(base64)
    }

    private func applyPendingPeerToken() async {
        guard let token = pendingPeerToken,
              let peerID = room?.peerUserID else { return }
        pendingPeerToken = nil
        await MainActor.run {
            NearbyInteractionService.shared.startPeerSession(
                peerUserID: peerID, tokenBase64: token)
        }
    }

    private func uwbLog(_ message: String) {
        UWBLogger.shared.append("[VM] \(message)")
    }

    private func appendUnique(_ msg: ChatMessageDTO) {
        guard !messages.contains(where: { $0.id == msg.id }) else { return }
        messages.append(msg)
        messages.sort { $0.timestamp < $1.timestamp }
    }
}
