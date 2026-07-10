import Foundation
import CoreLocation

enum RadarEvent: Sendable {
    case leftRadius(distanceMeters: Double)
    case pingReceived(PingNotificationDTO)
    case mutualMatch(roomID: UUID, peerUserID: UUID?)
}

// GPS-only real-time radar for a single joined event.
// Positioning uses WebSocket-pushed coordinates + device compass for direction.
// BLE is not used — GPS gives both distance and bearing.
actor EventRadarService {
    static let shared = EventRadarService()

    // Multi-subscriber broadcast. HomeView's consumer is torn down and recreated on
    // every tab switch (radar↔chat), and re-iterating a *single* AsyncStream across a
    // cancelled-then-recreated consumer silently degrades delivery after the first
    // cycle — the "works once, then stops" symptom. Each subscriber instead gets its
    // own stream (keyed below); every yield fans out to all live subscribers, and a
    // cancelled subscriber removes itself via onTermination. A short-lived overlap of
    // an old (dying) and new consumer is harmless — both receive the event.
    private var usersSubscribers: [UUID: AsyncStream<[NearbyUser]>.Continuation] = [:]
    private var eventSubscribers: [UUID: AsyncStream<RadarEvent>.Continuation] = [:]
    // Cached so a new subscriber can read the current roster immediately on subscribe.
    private(set) var currentNearbyUsers: [NearbyUser] = []

    private var eventID: UUID?
    private var ownRadarToken: String = ""
    private var ownUserID: UUID?

    private var roster: [String: EventRadarUserDTO] = [:]  // radarToken → identity + GPS
    private var seenPingIDs: Set<UUID> = []
    private var seenMatchRoomIDs: Set<UUID> = []

    // WebSocket
    private var wsTask: URLSessionWebSocketTask?
    private var wsReceiveTask: Task<Void, Never>?
    private var wsGeneration = 0

    // Background tasks
    private var pollTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var locationTask: Task<Void, Never>?
    private var headingTask: Task<Void, Never>?

    // Own position — updated from LocationService streams in real-time
    private var ownLocation: CLLocation? = nil
    private var ownHeading: Double = 0

    private let wsDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy  = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let wsEncoder = JSONEncoder()

    // MARK: - Lifecycle

    private init() {}

    // MARK: - Broadcast subscriptions

    // A new radar-blip subscription. Seeds nothing itself — the consumer reads
    // `currentNearbyUsers` first for an immediate value, then awaits updates here.
    func userUpdates() -> AsyncStream<[NearbyUser]> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            usersSubscribers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeSubscriber(usersID: id) }
            }
        }
    }

    // A new radar-event subscription (pings, mutual matches, left-radius).
    func events() -> AsyncStream<RadarEvent> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .unbounded) { continuation in
            eventSubscribers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeSubscriber(eventID: id) }
            }
        }
    }

    private func removeSubscriber(usersID: UUID) { usersSubscribers[usersID] = nil }
    private func removeSubscriber(eventID: UUID)  { eventSubscribers[eventID] = nil }

    private func broadcastUsers(_ users: [NearbyUser]) {
        for c in usersSubscribers.values { c.yield(users) }
    }

    func start(eventID: UUID, ownRadarToken: String, ownUserID: UUID, event: EventDTO) async {
        self.eventID      = eventID
        self.ownRadarToken = ownRadarToken
        self.ownUserID    = ownUserID
        roster.removeAll()
        seenPingIDs.removeAll()
        // Seed with matches that already existed before this session so they aren't
        // re-announced as brand-new — only rooms created *during* this radar session
        // should surface via .mutualMatch. Unread-message state is derived separately
        // and durably in AppState, so it needs no baseline here.
        let existingRooms = (try? await MatchService.shared.fetchMatches()) ?? []
        seenMatchRoomIDs = Set(existingRooms.map(\.id))

        await LocationService.shared.requestPermissionAndStart()

        let service = EventRadarService.shared
        locationTask = Task { await locationLoop(service: service) }
        headingTask  = Task { await headingLoop(service: service) }

        await connectWebSocket(eventID: eventID)

        // Fallback poll for roster sync (positions come via WS in real-time)
        pollTask = Task { await pollLoop() }
        startHeartbeat(event: event)
    }

    var isRunning: Bool { wsTask != nil }

    func stop() async {
        pollTask?.cancel();      pollTask = nil
        heartbeatTask?.cancel(); heartbeatTask = nil
        locationTask?.cancel();  locationTask = nil
        headingTask?.cancel();   headingTask = nil
        wsReceiveTask?.cancel(); wsReceiveTask = nil
        wsGeneration += 1
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        if let id = eventID { try? await EventService.shared.leave(eventID: id) }
        eventID    = nil
        ownLocation = nil
        ownHeading  = 0
        roster.removeAll()
        currentNearbyUsers = []
        broadcastUsers([])
    }

    // MARK: - Own position (called from streaming loops)

    func updateOwnLocation(_ location: CLLocation) {
        // Accept fixes up to 150 m — indoors GPS accuracy is typically 30–100 m
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy <= 150 else { return }
        ownLocation = location
        yieldUsers()
        Task { await sendLocationToWS(location) }
    }

    func updateOwnHeading(_ heading: Double) {
        ownHeading = heading
        yieldUsers()
    }

    // MARK: - WebSocket

    private func connectWebSocket(eventID: UUID) async {
        wsGeneration += 1
        let gen = wsGeneration
        guard let url = await APIClient.shared.webSocketURL(path: "/ws/radar/\(eventID.uuidString)") else { return }
        let task = WebSocketSession.shared.webSocketTask(with: url)
        wsTask = task
        task.resume()
        let service = EventRadarService.shared
        wsReceiveTask = Task { await service.wsReceiveLoop(eventID: eventID, task: task, generation: gen) }
    }

    private func wsReceiveLoop(eventID: UUID, task: URLSessionWebSocketTask, generation: Int) async {
        while !Task.isCancelled {
            do {
                let msg = try await task.receive()
                guard wsGeneration == generation else { return }
                switch msg {
                case .string(let text):      handleWSText(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) { handleWSText(text) }
                @unknown default: break
                }
            } catch { break }
        }
        // Connection dropped (network blip, idle timeout, brief backgrounding).
        // Without reconnecting, we'd silently downgrade to the ~30s poll fallback
        // for the rest of the session — reconnect as long as this generation and
        // event are still the active one (i.e. this wasn't superseded by a newer
        // connection or a stop()).
        guard !Task.isCancelled, wsGeneration == generation, self.eventID == eventID else { return }
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled, wsGeneration == generation, self.eventID == eventID else { return }
        await connectWebSocket(eventID: eventID)
    }

    private func handleWSText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let msg  = try? wsDecoder.decode(RadarSocketMessage.self, from: data) else { return }

        switch msg.event {

        case "roster":
            guard let pd = msg.payload.data(using: .utf8),
                  let list = try? wsDecoder.decode([EventRadarUserDTO].self, from: pd) else { return }
            roster = Dictionary(uniqueKeysWithValues: list.map { ($0.radarToken, $0) })
            yieldUsers()

        case "user_moved":
            guard let pd = msg.payload.data(using: .utf8),
                  let u  = try? wsDecoder.decode(UserPositionUpdate.self, from: pd),
                  let token = roster.values.first(where: { $0.userID == u.userID })?.radarToken
            else { return }
            roster[token]?.lat = u.lat
            roster[token]?.lng = u.lng
            yieldUsers()

        case "ping":
            guard let pd   = msg.payload.data(using: .utf8),
                  let ping = try? wsDecoder.decode(PingNotificationDTO.self, from: pd),
                  !seenPingIDs.contains(ping.fromUserID) else { return }
            seenPingIDs.insert(ping.fromUserID)
            emit(.pingReceived(ping))

        case "mutual_match":
            guard let pd = msg.payload.data(using: .utf8),
                  let mm = try? wsDecoder.decode(MutualMatchWS.self, from: pd) else { return }
            recordMutualMatch(roomID: mm.roomID, peerUserID: mm.peerUserID)

        case "left_radius":
            emit(.leftRadius(distanceMeters: 0))

        default: break
        }
    }

    private func sendLocationToWS(_ location: CLLocation) async {
        guard let task = wsTask else { return }
        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude
        let acc = location.horizontalAccuracy
        let payload = "{\"lat\":\(lat),\"lng\":\(lng),\"accuracy\":\(acc)}"
        let msg = RadarSocketMessage(event: "location", payload: payload)
        guard let data = try? wsEncoder.encode(msg),
              let text = String(data: data, encoding: .utf8) else { return }
        try? await task.send(.string(text))
    }

    // MARK: - Background loops

    private func locationLoop(service: EventRadarService) async {
        let stream = await LocationService.shared.locationUpdates()
        for await location in stream {
            await service.updateOwnLocation(location)
        }
    }

    private func headingLoop(service: EventRadarService) async {
        let stream = await LocationService.shared.headingUpdates()
        for await heading in stream {
            await service.updateOwnHeading(heading)
        }
    }

    // Fallback poll for when the WebSocket isn't delivering (down, backgrounded, flaky
    // local network). Positions still come via WS in real-time, but pings and mutual
    // matches must feel prompt even when WS is silent, so this runs every 5s and checks
    // all three each tick — that bounds worst-case latency to ~5s instead of the old
    // ~30s. Unread-message detection is NOT here; it's a direct poll in HomeView (see
    // HomeViewModel.refreshUnread) so the chat-bubble badge stays as snappy and reliable
    // as the chat list, independent of this stream.
    private func pollLoop() async {
        while !Task.isCancelled {
            guard let id = eventID else { break }
            if let list = try? await EventService.shared.fetchRadar(eventID: id) {
                roster = Dictionary(uniqueKeysWithValues: list.map { ($0.radarToken, $0) })
                yieldUsers()
            }
            if let pings = try? await PingService.shared.notifications(eventID: id) {
                for ping in pings where !seenPingIDs.contains(ping.fromUserID) {
                    seenPingIDs.insert(ping.fromUserID)
                    emit(.pingReceived(ping))
                }
            }
            // Fallback for mutual matches missed over WS (e.g. app was backgrounded when
            // the peer's reciprocal ping came in) — without this, the original pinger
            // would only ever learn about it by pinging again themselves.
            if let rooms = try? await MatchService.shared.fetchMatches() {
                for room in rooms where !seenMatchRoomIDs.contains(room.id) {
                    recordMutualMatch(roomID: room.id, peerUserID: room.peerUserID)
                }
            }
            try? await Task.sleep(for: .seconds(5))
        }
    }

    // MARK: - Heartbeat (auto-disarm when leaving venue radius)

    private func startHeartbeat(event: EventDTO) {
        let service = EventRadarService.shared
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let id  = await service.currentEventID,
                      let loc = await LocationService.shared.currentLocation else { continue }
                if let resp = try? await EventService.shared.heartbeat(
                    eventID: id,
                    latitude:  loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude),
                   !resp.radarEligible {
                    await service.emit(.leftRadius(distanceMeters: resp.distanceMeters))
                }
            }
        }
    }

    var currentEventID: UUID? { eventID }
    func emit(_ event: RadarEvent) {
        for c in eventSubscribers.values { c.yield(event) }
    }

    // Shared by the WS "mutual_match" push and the poll fallback below so a match
    // discovered either way is only ever surfaced to the UI once.
    private func recordMutualMatch(roomID: UUID, peerUserID: UUID?) {
        guard !seenMatchRoomIDs.contains(roomID) else { return }
        seenMatchRoomIDs.insert(roomID)
        emit(.mutualMatch(roomID: roomID, peerUserID: peerUserID))
    }

    // MARK: - Build radar blips (GPS-only)

    private func yieldUsers() {
        let users: [NearbyUser] = roster.values.map { entry in
            guard let myLoc = ownLocation,
                  let lat   = entry.lat,
                  let lng   = entry.lng else {
                // Peer GPS not received yet — show as locating
                return NearbyUser(
                    id: entry.userID, nickname: entry.nickname, age: entry.age,
                    photoURL: entry.photoURL, interests: entry.interests, status: entry.status,
                    distance: 0, direction: nil, hasRealPosition: false)
            }
            let peerCoord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            let bearing   = gpsBearing(from: myLoc.coordinate, to: peerCoord)
            let direction = Float(bearing - ownHeading * .pi / 180)
            let distance  = Float(haversineMeters(from: myLoc.coordinate, to: peerCoord))
            return NearbyUser(
                id: entry.userID, nickname: entry.nickname, age: entry.age,
                photoURL: entry.photoURL, interests: entry.interests, status: entry.status,
                distance: max(distance, 0.5), direction: direction, hasRealPosition: true)
        }
        currentNearbyUsers = users
        broadcastUsers(users)
    }

    // MARK: - Geo helpers

    private func gpsBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude  * .pi / 180
        let lat2 = to.latitude    * .pi / 180
        let dLon = (to.longitude  - from.longitude) * .pi / 180
        let y    = sin(dLon) * cos(lat2)
        let x    = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return atan2(y, x)
    }

    private func haversineMeters(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let R  = 6_371_000.0
        let φ1 = from.latitude  * .pi / 180
        let φ2 = to.latitude    * .pi / 180
        let Δφ = (to.latitude   - from.latitude)  * .pi / 180
        let Δλ = (to.longitude  - from.longitude) * .pi / 180
        let a  = sin(Δφ/2) * sin(Δφ/2) + cos(φ1) * cos(φ2) * sin(Δλ/2) * sin(Δλ/2)
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
