import Observation
import Foundation

private struct StatusBody: Sendable {
    let status: String
}
extension StatusBody: Encodable {
    private enum CodingKeys: CodingKey { case status }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(status, forKey: .status)
    }
}

@Observable
@MainActor
final class HomeViewModel {
    var nearbyUsers: [NearbyUser] = []
    var errorMessage: String? = nil
    var banner: Banner? = nil
    var selfHeadingDegrees: Double = 0

    // Persistent feed behind the bottom carousel — most recent first, one
    // entry per sender (a repeat ping just bumps their card to the front).
    var receivedPings: [PingNotificationDTO] = []

    // Matches the *other* side learned about via WS/poll (not their own completing
    // ping) — surfaced in the notify log instead of force-navigating them into the
    // room. Most recent first, one entry per room.
    var recentMatches: [RoomDTO] = []

    // Radar/BLE only turns on once the user explicitly taps to connect —
    // arriving at Home no longer auto-activates it.
    var isConnected = false
    var isConnecting = false

    // Set by HomeView when a room is created from a mutual match, to trigger navigation.
    var pendingRoomID: UUID? = nil
    var radarDisarmed = false   // set true when heartbeat reports we left the radius

    struct Banner: Equatable {
        enum Kind { case ping, match, pingSent }
        let kind: Kind
        let text: String
    }

    private var usersTask: Task<Void, Never>? = nil
    private var eventsTask: Task<Void, Never>? = nil
    private var bannerClearTask: Task<Void, Never>? = nil
    // Bumped on every subscribeStreams() call. A task closure only clears its own
    // stored reference if its generation is still current — otherwise a cancelled-
    // but-not-yet-unwound task from a previous subscription would blindly nil out
    // a newer, still-live task's reference once it finally notices cancellation.
    private var subscriptionGeneration = 0

    // Stashed so handle(_:) can reach it for unseen-match bookkeeping —
    // RadarEvent.mutualMatch arrives outside any per-call appState parameter.
    private weak var appState: AppState?

    // Resubscribes to whatever radar session is already running — used when
    // returning to an already-connected Home (e.g. switching tabs and back).
    func start(appState: AppState) async {
        self.appState = appState
        if !isConnected {
            // Optimistically show connected UI when there's an active event so we don't
            // flash TapToConnectView during the async actor call below.
            if appState.activeEvent != nil { isConnected = true }
            let running = await EventRadarService.shared.isRunning
            if !running { isConnected = false; return }
            isConnected = true
        }
        subscribeStreams()
    }

    func stop() {
        usersTask?.cancel(); usersTask = nil
        eventsTask?.cancel(); eventsTask = nil
    }

    func updateStatus(_ status: String) async {
        let trimmed = status.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? await APIClient.shared.patch("me", body: StatusBody(status: String(trimmed.prefix(100))))
    }

    // Explicit "Tap to Connect" action — this is what actually arms BLE
    // advertising/scanning, not just arriving at the Home tab.
    func connect(appState: AppState) async {
        self.appState = appState
        guard let event = appState.activeEvent, let userID = appState.currentUser?.id else { return }
        isConnecting = true
        defer { isConnecting = false }

        // Derive a short stable 8-byte hex token from the user's UUID (first 8 bytes)
        let token: String = {
            let bytes = withUnsafeBytes(of: userID.uuid) { Array($0) } // 16 bytes
            // Take first 8 bytes and format as 16 lowercase hex chars
            return bytes.prefix(8).map { String(format: "%02x", $0) }.joined()
        }()

        HapticManager.shared.startEngine()
        await EventRadarService.shared.start(eventID: event.id, ownRadarToken: token, ownUserID: userID, event: event)
        isConnected = true
        subscribeStreams()
    }

    // Idempotent — start(appState:) calls this every time HomeView reappears (tab
    // switch back, popping from a pushed room, dismissing a sheet), which can fire
    // far more often than a genuine "radar session changed". Each reappear opens a
    // fresh per-subscriber broadcast stream from EventRadarService (see userUpdates()/
    // events()), so a brief overlap between an old, cancelled-but-not-yet-unwound
    // consumer and the new one is harmless — both receive every yield. Each task clears
    // its own stored reference to nil right as its stream ends (rather than relying on a
    // nil-check alone) — a `Task` reference stays non-nil even after the task naturally
    // finishes, and the subscriptionGeneration guard stops a stale task from nil-ing a
    // newer, still-live task's reference.
    private func subscribeStreams() {
        guard usersTask == nil, eventsTask == nil else { return }
        subscriptionGeneration += 1
        let myGeneration = subscriptionGeneration
        let radar = EventRadarService.shared
        usersTask = Task { @MainActor [weak self] in
            // Seed immediately with cached value so the radar isn't empty on re-subscribe
            let current = await radar.currentNearbyUsers
            self?.nearbyUsers = current
            for await users in await radar.userUpdates() {
                self?.nearbyUsers = users
            }
            if self?.subscriptionGeneration == myGeneration { self?.usersTask = nil }
        }
        eventsTask = Task { @MainActor [weak self] in
            for await event in await radar.events() {
                self?.handle(event)
            }
            if self?.subscriptionGeneration == myGeneration { self?.eventsTask = nil }
        }
    }

    // Direct unread-badge poll for the chat-bubble red dot, driven by HomeView's .task
    // (auto-cancelled on disappear). Mirrors MatchesViewModel's 5s poll so the badge on
    // radar is exactly as prompt and reliable as the chat-list highlight — and, being a
    // pure recompute from durable state, is immune to the radar event-stream's churn.
    func refreshUnread(appState: AppState, ownUserID: UUID?) async {
        guard let rooms = try? await MatchService.shared.fetchMatches() else { return }
        appState.recomputeUnread(from: rooms, ownUserID: ownUserID)
    }

    private func handle(_ event: RadarEvent) {
        switch event {
        case .pingReceived(let ping):
            HapticManager.shared.play(.receivePing)
            showBanner(.init(kind: .ping, text: "\(ping.fromNickname), \(ping.fromAge) pinged you"))
            receivedPings.removeAll { $0.fromUserID == ping.fromUserID }
            receivedPings.insert(ping, at: 0)
        case .mutualMatch(let roomID, let peerUserID):
            // This is the *other* side of someone else's completing ping — surface it
            // via the notify log instead of force-navigating; the completer (below, in
            // sendPing) still gets taken straight into the room since they took the action.
            HapticManager.shared.play(.mutualMatch)
            if let peerUserID { receivedPings.removeAll { $0.fromUserID == peerUserID } }
            let peerNickname = peerUserID.flatMap { id in nearbyUsers.first(where: { $0.id == id })?.nickname }
            showBanner(.init(kind: .match, text: peerNickname.map { "Matched with \($0)!" } ?? "You got a match!"))
            Task {
                let (_, room) = await resolveRoom(roomID: roomID, peerUserID: peerUserID)
                // Chat bubble red dot is unread-messages-only now — a brand-new match is
                // announced via the notify log's "Matches" section instead (below).
                recordRecentMatch(room)
            }
        case .leftRadius:
            HapticManager.shared.play(.error)
            radarDisarmed = true
        }
    }

    // On-screen fallback ping (also the path used when the user taps a blip).
    func sendPing(to user: NearbyUser, appState: AppState) async {
        guard let eventID = appState.activeEventID else { return }
        HapticManager.shared.play(.sendPing)
        do {
            let resp = try await PingService.shared.ping(eventID: eventID, toUserID: user.id)
            if resp.mutual, let roomID = resp.roomID {
                HapticManager.shared.play(.mutualMatch)
                showBanner(.init(kind: .match, text: "Matched with \(user.nickname)!"))
                receivedPings.removeAll { $0.fromUserID == user.id }
                let (resolvedRoomID, room) = await resolveRoom(roomID: roomID, peerUserID: user.id)
                recordRecentMatch(room)
                pendingRoomID = resolvedRoomID
            } else {
                showBanner(.init(kind: .pingSent, text: "Ping Sent"))
            }
        } catch {
            errorMessage = "Couldn't send ping."
        }
    }

    // Prefer an existing room with this peer so chat history is preserved across events.
    // Also returns the matched RoomDTO when resolvable, for the notify log's match entry.
    func resolveRoom(roomID: UUID, peerUserID: UUID?) async -> (roomID: UUID, room: RoomDTO?) {
        guard let peerUserID else { return (roomID, nil) }
        if let rooms = try? await MatchService.shared.fetchMatches(),
           let existing = rooms.first(where: { $0.peerUserID == peerUserID }) {
            return (existing.id, existing)
        }
        return (roomID, nil)
    }

    private func recordRecentMatch(_ room: RoomDTO?) {
        guard let room else { return }
        recentMatches.removeAll { $0.id == room.id }
        recentMatches.insert(room, at: 0)
    }

    // Focus a blip so the Back Tap PingIntent targets it.
    func focus(_ user: NearbyUser, appState: AppState) {
        appState.focusTargetUserID = user.id
    }

    func leaveRadar(appState: AppState) async {
        await EventRadarService.shared.stop()
        HapticManager.shared.stopEngine()
        isConnected = false
        appState.activeEvent = nil
        appState.activeEventID = nil
        appState.focusTargetUserID = nil
    }

    private func showBanner(_ b: Banner) {
        banner = b
        bannerClearTask?.cancel()
        bannerClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            self?.banner = nil
        }
    }
}

