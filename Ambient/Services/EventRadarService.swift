import Foundation
import CoreLocation

// Events emitted to the radar UI beyond the nearby-users stream.
enum RadarEvent: Sendable {
    case leftRadius(distanceMeters: Double)   // heartbeat reported user left 500m → auto-disarm
    case pingReceived(PingNotificationDTO)    // someone pinged us on this event
    case mutualMatch(roomID: UUID)            // our own ping became mutual (from ping response)
}

// Orchestrates Tier-1 (GPS gate) + Tier-2 (BLE radar) for a single joined event.
actor EventRadarService {
    static let shared = EventRadarService()

    private let ble = BLERadar()

    private(set) var nearbyUsersStream: AsyncStream<[NearbyUser]>
    private var usersContinuation: AsyncStream<[NearbyUser]>.Continuation?
    private(set) var eventStream: AsyncStream<RadarEvent>
    private var eventContinuation: AsyncStream<RadarEvent>.Continuation?

    private var eventID: UUID?
    private var ownRadarToken: String = ""

    private var roster: [String: EventRadarUserDTO] = [:]  // radarToken → identity
    private var rssiByToken: [String: Int] = [:]           // radarToken → smoothed RSSI
    private var seenPingIDs: Set<UUID> = []

    private var pollTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?

    // MARK: - Lifecycle

    private init() {
        var uc: AsyncStream<[NearbyUser]>.Continuation?
        nearbyUsersStream = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { uc = $0 }
        usersContinuation = uc
        var ec: AsyncStream<RadarEvent>.Continuation?
        eventStream = AsyncStream(bufferingPolicy: .unbounded) { ec = $0 }
        eventContinuation = ec
    }

    // Streams are (re)created on start so a fresh radar session gets clean buffers.
    private func makeStreams() {
        var uc: AsyncStream<[NearbyUser]>.Continuation?
        nearbyUsersStream = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { uc = $0 }
        usersContinuation = uc
        var ec: AsyncStream<RadarEvent>.Continuation?
        eventStream = AsyncStream(bufferingPolicy: .unbounded) { ec = $0 }
        eventContinuation = ec
    }

    func start(eventID: UUID, ownRadarToken: String, event: EventDTO) async {
        self.eventID = eventID
        self.ownRadarToken = ownRadarToken
        roster.removeAll()
        rssiByToken.removeAll()
        seenPingIDs.removeAll()
        makeStreams()

        let service = EventRadarService.shared
        ble.onPeerRSSI = { token, rssi in
            Task { await service.applyRSSI(token: token, rssi: rssi) }
        }
        ble.onPeerLost = { token in
            Task { await service.removeRSSI(token: token) }
        }
        ble.start(ownRadarToken: ownRadarToken)

        await LocationService.shared.requestPermissionAndStart()
        startHeartbeat(event: event)
        pollTask = Task { await pollLoop() }
    }

    func stop() async {
        pollTask?.cancel(); pollTask = nil
        heartbeatTask?.cancel(); heartbeatTask = nil
        ble.stop()
        if let id = eventID { try? await EventService.shared.leave(eventID: id) }
        eventID = nil
        roster.removeAll()
        rssiByToken.removeAll()
        usersContinuation?.yield([])
    }

    // MARK: - BLE correlation

    private func applyRSSI(token: String, rssi: Int) {
        rssiByToken[token] = rssi
        yieldUsers()
    }

    private func removeRSSI(token: String) {
        rssiByToken.removeValue(forKey: token)
        yieldUsers()
    }

    // MARK: - Server polling (roster + ping notifications)

    private func pollLoop() async {
        var tick = 0
        while !Task.isCancelled {
            guard let id = eventID else { break }
            if let list = try? await EventService.shared.fetchRadar(eventID: id) {
                roster = Dictionary(uniqueKeysWithValues: list.map { ($0.radarToken, $0) })
                // Drop RSSI for anyone no longer on the roster.
                rssiByToken = rssiByToken.filter { roster[$0.key] != nil }
                yieldUsers()
            }
            if tick % 2 == 0, let pings = try? await PingService.shared.notifications(eventID: id) {
                for ping in pings where !seenPingIDs.contains(ping.fromUserID) {
                    seenPingIDs.insert(ping.fromUserID)
                    eventContinuation?.yield(.pingReceived(ping))
                }
            }
            tick += 1
            try? await Task.sleep(for: .seconds(3))
        }
    }

    // MARK: - Heartbeat (Tier-1 auto-disarm)

    private func startHeartbeat(event: EventDTO) {
        let service = EventRadarService.shared
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let id = await service.currentEventID,
                      let loc = await LocationService.shared.currentLocation else { continue }
                if let resp = try? await EventService.shared.heartbeat(
                    eventID: id, latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude),
                   !resp.radarEligible {
                    await service.emit(.leftRadius(distanceMeters: resp.distanceMeters))
                }
            }
        }
    }

    var currentEventID: UUID? { eventID }
    func emit(_ event: RadarEvent) { eventContinuation?.yield(event) }

    // MARK: - Build radar blips

    private func yieldUsers() {
        let users: [NearbyUser] = roster.values.map { entry in
            if let rssi = rssiByToken[entry.radarToken] {
                let meters = RSSIDistance.meters(rssi: rssi)
                return NearbyUser(id: entry.userID, nickname: entry.nickname, age: entry.age,
                                  distance: max(meters, 0.5), direction: nil, elevation: nil,
                                  hasRealPosition: true, distanceSource: .ble)
            }
            // Listed on server but no BLE hit yet — show as locating.
            return NearbyUser(id: entry.userID, nickname: entry.nickname, age: entry.age,
                              distance: 0, direction: nil, elevation: nil,
                              hasRealPosition: false, distanceSource: .unknown)
        }
        usersContinuation?.yield(users)
    }
}
