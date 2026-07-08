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

    private(set) var nearbyUsersStream: AsyncStream<[NearbyUser]>
    private var usersContinuation: AsyncStream<[NearbyUser]>.Continuation?
    // Cached so new subscribers can read the current roster immediately on re-subscribe
    private(set) var currentNearbyUsers: [NearbyUser] = []
    private(set) var eventStream: AsyncStream<RadarEvent>
    private var eventContinuation: AsyncStream<RadarEvent>.Continuation?

    private var eventID: UUID?
    private var ownRadarToken: String = ""

    private var roster: [String: EventRadarUserDTO] = [:]  // radarToken → identity + GPS
    private var seenPingIDs: Set<UUID> = []

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

    private init() {
        var uc: AsyncStream<[NearbyUser]>.Continuation?
        nearbyUsersStream = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { uc = $0 }
        usersContinuation = uc
        var ec: AsyncStream<RadarEvent>.Continuation?
        eventStream = AsyncStream(bufferingPolicy: .unbounded) { ec = $0 }
        eventContinuation = ec
    }

    private func makeStreams() {
        var uc: AsyncStream<[NearbyUser]>.Continuation?
        nearbyUsersStream = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { uc = $0 }
        usersContinuation = uc
        var ec: AsyncStream<RadarEvent>.Continuation?
        eventStream = AsyncStream(bufferingPolicy: .unbounded) { ec = $0 }
        eventContinuation = ec
    }

    func start(eventID: UUID, ownRadarToken: String, event: EventDTO) async {
        self.eventID      = eventID
        self.ownRadarToken = ownRadarToken
        roster.removeAll()
        seenPingIDs.removeAll()
        makeStreams()

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
        usersContinuation?.yield([])
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
        let task = URLSession.shared.webSocketTask(with: url)
        wsTask = task
        task.resume()
        let service = EventRadarService.shared
        wsReceiveTask = Task { await service.wsReceiveLoop(task: task, generation: gen) }
    }

    private func wsReceiveLoop(task: URLSessionWebSocketTask, generation: Int) async {
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
            eventContinuation?.yield(.pingReceived(ping))

        case "mutual_match":
            guard let pd = msg.payload.data(using: .utf8),
                  let mm = try? wsDecoder.decode(MutualMatchWS.self, from: pd) else { return }
            eventContinuation?.yield(.mutualMatch(roomID: mm.roomID, peerUserID: mm.peerUserID))

        case "left_radius":
            eventContinuation?.yield(.leftRadius(distanceMeters: 0))

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

    // Roster sync fallback — positions come via WS so interval can be long
    private func pollLoop() async {
        var tick = 0
        while !Task.isCancelled {
            guard let id = eventID else { break }
            if let list = try? await EventService.shared.fetchRadar(eventID: id) {
                roster = Dictionary(uniqueKeysWithValues: list.map { ($0.radarToken, $0) })
                yieldUsers()
            }
            if tick % 2 == 0, let pings = try? await PingService.shared.notifications(eventID: id) {
                for ping in pings where !seenPingIDs.contains(ping.fromUserID) {
                    seenPingIDs.insert(ping.fromUserID)
                    eventContinuation?.yield(.pingReceived(ping))
                }
            }
            tick += 1
            try? await Task.sleep(for: .seconds(15))
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
    func emit(_ event: RadarEvent) { eventContinuation?.yield(event) }

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
        usersContinuation?.yield(users)
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
