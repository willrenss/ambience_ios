import Observation
import Foundation
<<<<<<< HEAD
import CoreLocation

private struct EmptyBody: Encodable {}
=======
>>>>>>> c5f4022 (Iniatial Commit)

@Observable
@MainActor
final class HomeViewModel {
<<<<<<< HEAD
    var isOpen: Bool = false
    var nearbyUsers: [NearbyUser] = []
    var currentVenue: VenueDTO? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var lastWaveFrom: String? = nil  // shown briefly in UI
    var uwbDebugStatus: String = ""
    var gpsDebugStatus: String = ""

    private let proximityService: any ProximityServiceProtocol = ServerProximityService.shared
    private var waveTask: Task<Void, Never>? = nil
    private var lastWaveCheck: Date = .distantPast

    func toggleStatus() async {
        isOpen.toggle()
        LocationService.setIsOpen(isOpen)
        if isOpen {
            await setPresence(open: true)
            await startProximityScanning()
            startWavePolling()
            HapticManager.shared.playLightTap()
        } else {
            await setPresence(open: false)
            await stopProximityScanning()
            stopWavePolling()
            nearbyUsers = []
        }
    }

    func startProximityScanning() async {
        do {
            try await proximityService.startScanning()
            // Read stream AFTER startScanning so we get the freshly created one
            let stream = await proximityService.nearbyUsersStream
            Task { @MainActor [weak self] in
                for await users in stream {
                    self?.nearbyUsers = users
                    self?.uwbDebugStatus = NearbyInteractionService.shared.debugStatus
                    // GPS status for diagnosing "no direction" issues
                    let loc = await LocationService.shared.currentLocation
                    let withCoords = users.filter { $0.distanceSource == .gps || $0.distanceSource == .uwb }.count
                    if let loc {
                        self?.gpsDebugStatus = String(format: "GPS: ±%.0fm | dir=%d/%d",
                            loc.horizontalAccuracy, withCoords, users.count)
                    } else {
                        self?.gpsDebugStatus = "GPS: no fix | dir=\(withCoords)/\(users.count)"
                    }
                }
            }
        } catch {
            errorMessage = "Could not start proximity scanning."
        }
    }

    func stopProximityScanning() async {
        await proximityService.stopScanning()
    }

    func handleSearchNearbyNotification() async {
        guard !isOpen else { return }
        await toggleStatus()
    }

    func sendWave() async {
        do {
            try await APIClient.shared.post("/presence/wave", body: EmptyBody())
            HapticManager.shared.playLightTap()
        } catch {}
    }

    private func setPresence(open: Bool) async {
        await ServerProximityService.shared.updatePresence(isOpen: open)
    }

    // MARK: - Wave polling

    private func startWavePolling() {
        waveTask?.cancel()
        lastWaveCheck = Date()
        waveTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await self?.checkWaves()
            }
        }
    }

    private func stopWavePolling() {
        waveTask?.cancel()
        waveTask = nil
    }

    private func checkWaves() async {
        struct WaveResp: Decodable {
            let fromDisplayName: String
            let timestamp: Date
        }
        do {
            let waves: [WaveResp] = try await APIClient.shared.get("/presence/waves")
            let newWaves = waves.filter { $0.timestamp > lastWaveCheck }
            lastWaveCheck = Date()
            guard let latest = newWaves.last else { return }

            HapticManager.shared.playWaveHaptic()
            lastWaveFrom = latest.fromDisplayName
            // Clear the banner after 3 seconds
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                self?.lastWaveFrom = nil
            }
        } catch {}
    }
=======
    var nearbyUsers: [NearbyUser] = []
    var errorMessage: String? = nil
    var banner: Banner? = nil
    var selfHeadingDegrees: Double = 0

    // Persistent feed behind the bottom carousel — most recent first, one
    // entry per sender (a repeat ping just bumps their card to the front).
    var receivedPings: [PingNotificationDTO] = []

    // Radar/BLE only turns on once the user explicitly taps to connect —
    // arriving at Home no longer auto-activates it.
    var isConnected = false
    var isConnecting = false

    // Set by HomeView when a room is created from a mutual match, to trigger navigation.
    var pendingRoomID: UUID? = nil
    var radarDisarmed = false   // set true when heartbeat reports we left the radius

    struct Banner: Equatable {
        enum Kind { case ping, match }
        let kind: Kind
        let text: String
    }

    private var usersTask: Task<Void, Never>? = nil
    private var eventsTask: Task<Void, Never>? = nil
    private var bannerClearTask: Task<Void, Never>? = nil

    // Resubscribes to whatever radar session is already running — used when
    // returning to an already-connected Home (e.g. switching tabs and back).
    func start(appState: AppState) {
        guard isConnected else { return }
        subscribeStreams()
    }

    func stop() {
        usersTask?.cancel(); usersTask = nil
        eventsTask?.cancel(); eventsTask = nil
    }

    // Explicit "Tap to Connect" action — this is what actually arms BLE
    // advertising/scanning, not just arriving at the Home tab.
    func connect(appState: AppState) async {
        guard let event = appState.activeEvent, let userID = appState.currentUser?.id else { return }
        isConnecting = true
        defer { isConnecting = false }

        let token = RadarToken.derive(from: userID)
        HapticManager.shared.startEngine()
        await EventRadarService.shared.start(eventID: event.id, ownRadarToken: token, event: event)
        isConnected = true
        subscribeStreams()
    }

    private func subscribeStreams() {
        let radar = EventRadarService.shared
        usersTask?.cancel()
        usersTask = Task { @MainActor [weak self] in
            let stream = await radar.nearbyUsersStream
            for await users in stream {
                self?.nearbyUsers = users
            }
        }
        eventsTask?.cancel()
        eventsTask = Task { @MainActor [weak self] in
            let stream = await radar.eventStream
            for await event in stream {
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: RadarEvent) {
        switch event {
        case .pingReceived(let ping):
            HapticManager.shared.play(.receivePing)
            showBanner(.init(kind: .ping, text: "\(ping.fromNickname), \(ping.fromAge) pinged you"))
            receivedPings.removeAll { $0.fromUserID == ping.fromUserID }
            receivedPings.insert(ping, at: 0)
        case .mutualMatch(let roomID):
            HapticManager.shared.play(.mutualMatch)
            pendingRoomID = roomID
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
                pendingRoomID = roomID
            }
        } catch {
            errorMessage = "Couldn't send ping."
        }
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
>>>>>>> c5f4022 (Iniatial Commit)
}
