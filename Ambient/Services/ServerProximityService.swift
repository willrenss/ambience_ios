import Foundation
import CoreLocation

actor ServerProximityService: ProximityServiceProtocol {
    static let shared = ServerProximityService()

    private(set) var nearbyUsersStream: AsyncStream<[NearbyUser]>
    private var streamContinuation: AsyncStream<[NearbyUser]>.Continuation?
    private var pollTask: Task<Void, Never>?
    private var tick = 0
    private var knownPeers: [UUID: String] = [:]

    private var lastServerPeers: [NearbyUserDTO] = []
    private var lastMyLoc: CLLocation?
    private var lastMyHeadRad: Float = 0
    // NI results cached here so updates yield immediately without a MainActor hop
    private var lastNIResults: [UUID: (distance: Float, direction: Float?)] = [:]

    init() {
        var c: AsyncStream<[NearbyUser]>.Continuation?
        nearbyUsersStream = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { c = $0 }
        streamContinuation = c
    }

    private func resetStream() {
        var c: AsyncStream<[NearbyUser]>.Continuation?
        nearbyUsersStream = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { c = $0 }
        streamContinuation = c
    }

    func startScanning() async throws {
        pollTask?.cancel()
        tick = 0
        knownPeers.removeAll()
        lastServerPeers.removeAll()
        lastNIResults.removeAll()
        resetStream()

        await LocationService.shared.requestPermissionAndStart()

        let service = ServerProximityService.shared
        await MainActor.run {
            NearbyInteractionService.shared.onNIUpdate = { peerID, distance, direction in
                Task { await service.applyNIUpdate(peerID: peerID, distance: distance, direction: direction) }
            }
            NearbyInteractionService.shared.onNIRemove = { peerID in
                Task { await service.removeNIResult(peerID: peerID) }
            }
            // Token arrived after prepare() timed out — re-upload presence with the real token
            NearbyInteractionService.shared.onTokenReady = {
                Task { await service.updatePresence(isOpen: true) }
            }
        }

        // Prepare UWB token in background — don't block the poll.
        // As soon as the token is ready we upload presence so the peer can start NI.
        // The poll already starts below and shows GPS/locating dots in the meantime.
        Task {
            await NearbyInteractionService.shared.prepare()
            await service.updatePresence(isOpen: true)
        }

        BLEProximityTrigger.shared.onNearbyAppDetected = {
            Task { await service.fetchAndYield() }
        }
        BLEProximityTrigger.shared.start()

        pollTask = Task { await poll() }
    }

    func stopScanning() async {
        pollTask?.cancel()
        pollTask = nil
        tick = 0
        knownPeers.removeAll()
        lastServerPeers.removeAll()
        lastNIResults.removeAll()
        BLEProximityTrigger.shared.stop()
        await LocationService.shared.stop()
        await MainActor.run {
            NearbyInteractionService.shared.stop()  // clears callbacks too
        }
        streamContinuation?.yield([])
    }

    // Called by NI delegate: store device-frame bearing directly.
    // Heading-up radar: 0 = front of phone = top of radar — no conversion needed.
    func applyNIUpdate(peerID: UUID, distance: Float, direction: Float?) {
        lastNIResults[peerID] = (distance, direction)
        guard !lastServerPeers.isEmpty else { return }
        streamContinuation?.yield(
            buildUsers(from: lastServerPeers, niResults: lastNIResults, myLoc: lastMyLoc)
        )
    }

    // Re-yield on heading change so GPS dots update their device-relative direction
    // as the user rotates. NI dots are already in device-frame so they're unaffected.
    func updateHeading(_ degrees: Double) {
        lastMyHeadRad = Float(degrees * .pi / 180)
        guard !lastServerPeers.isEmpty else { return }
        streamContinuation?.yield(
            buildUsers(from: lastServerPeers, niResults: lastNIResults, myLoc: lastMyLoc)
        )
    }

    func removeNIResult(peerID: UUID) {
        lastNIResults.removeValue(forKey: peerID)
        guard !lastServerPeers.isEmpty else { return }
        streamContinuation?.yield(
            buildUsers(from: lastServerPeers, niResults: lastNIResults, myLoc: lastMyLoc)
        )
    }

    func updatePresence(isOpen: Bool) async {
        let loc = await LocationService.shared.currentLocation
        let tokenBase64: String? = await MainActor.run {
            NearbyInteractionService.shared.ownToken
                .flatMap { NearbyInteractionService.encode($0) }
        }
        let body = PresenceRequestBody(
            isOpen: isOpen,
            latitude: loc?.coordinate.latitude,
            longitude: loc?.coordinate.longitude,
            horizontalAccuracy: loc?.horizontalAccuracy,
            discoveryToken: tokenBase64
        )
        do { try await APIClient.shared.post("/presence", body: body) } catch {}
    }

    // Fetch /presence/nearby and yield — used by poll loop and BLE trigger
    func fetchAndYield() async {
        do {
            let myLoc     = await LocationService.shared.currentLocation
            let myHeading = await LocationService.shared.headingDegrees
            let myHeadRad = Float((myHeading ?? 0) * .pi / 180)

            let response: [NearbyUserDTO] = try await APIClient.shared.get("/presence/nearby")

            for peer in response {
                knownPeers[peer.userID] = peer.displayName
                if let token = peer.discoveryToken {
                    let uid = peer.userID
                    await MainActor.run {
                        NearbyInteractionService.shared.startPeerSession(
                            peerUserID: uid, tokenBase64: token)
                    }
                }
            }

            lastServerPeers = response
            lastMyLoc       = myLoc
            lastMyHeadRad   = myHeadRad   // keeps applyNIUpdate's conversion accurate

            // Use cached lastNIResults (compass bearings, pre-converted in applyNIUpdate)
            streamContinuation?.yield(
                buildUsers(from: response, niResults: lastNIResults, myLoc: myLoc)
            )
        } catch {}
    }

    private func poll() async {
        while !Task.isCancelled {
            // Skip tick=0 presence upload — background Task in startScanning() handles the
            // first upload WITH the UWB token. If we upload here at tick=0 (token not ready
            // yet), the no-token POST can race against and overwrite the token POST.
            if tick > 0 && tick % 10 == 0 { await updatePresence(isOpen: true) }
            tick += 1
            await fetchAndYield()
            // First 6 polls: every 0.5s so NI token exchange happens fast.
            // After that: settle to 1s to save battery.
            let interval: Double = tick <= 6 ? 0.5 : 1.0
            try? await Task.sleep(for: .seconds(interval))
        }
    }

    // Heading-up radar: top = direction phone is pointing.
    // NI direction is already device-frame (0 = front). GPS compass bearing is
    // converted to device-relative by subtracting the phone's current heading.
    private func buildUsers(from peers: [NearbyUserDTO],
                            niResults: [UUID: (distance: Float, direction: Float?)],
                            myLoc: CLLocation?) -> [NearbyUser] {
        let headRad = lastMyHeadRad  // read once outside closure; avoids actor-isolation ambiguity
        return peers.map { r in
            // ── UWB path ──────────────────────────────────────────────────────────
            if let ni = niResults[r.userID] {
                if let dir = ni.direction {
                    // Best: UWB distance + UWB direction (device-frame, no conversion needed)
                    return NearbyUser(id: r.userID, displayName: r.displayName,
                                      distance: ni.distance, direction: dir,
                                      isOpen: true, hasRealPosition: true,
                                      distanceSource: .uwb)
                }
                // UWB distance only — GPS compass bearing converted to device-relative
                let gpsDir = Self.gpsBearing(from: myLoc, toLat: r.latitude, toLon: r.longitude)
                                 .map { $0 - headRad }
                return NearbyUser(id: r.userID, displayName: r.displayName,
                                  distance: ni.distance, direction: gpsDir,
                                  isOpen: true, hasRealPosition: true,
                                  distanceSource: .uwb)
            }

            // ── GPS-only path ─────────────────────────────────────────────────────
            if let myLoc, let lat = r.latitude, let lon = r.longitude {
                let dest    = CLLocation(latitude: lat, longitude: lon)
                let dist    = Float(myLoc.distance(from: dest))
                let bearing = Self.gpsBearing(from: myLoc, toLat: lat, toLon: lon)
                let deviceDir = bearing.map { $0 - headRad }
                return NearbyUser(id: r.userID, displayName: r.displayName,
                                  distance: max(dist, 0.5),
                                  direction: deviceDir,
                                  isOpen: true, hasRealPosition: true,
                                  distanceSource: .gps)
            }

            // No position data at all
            return NearbyUser(id: r.userID, displayName: r.displayName,
                              distance: 0, direction: nil,
                              isOpen: true, hasRealPosition: false,
                              distanceSource: .unknown)
        }
    }

    // Compass bearing (radians, clockwise from North) from origin to peer.
    // Returns nil only when origin has no valid fix or peer has no coordinates.
    private static func gpsBearing(from origin: CLLocation?,
                                   toLat: Double?, toLon: Double?) -> Float? {
        guard let origin, let lat2 = toLat, let lon2 = toLon,
              origin.horizontalAccuracy > 0 else { return nil }
        let lat1r = origin.coordinate.latitude  * .pi / 180
        let lon1r = origin.coordinate.longitude * .pi / 180
        let lat2r = lat2 * .pi / 180
        let dLon  = lon2 * .pi / 180 - lon1r
        let y = sin(dLon) * cos(lat2r)
        let x = cos(lat1r) * sin(lat2r) - sin(lat1r) * cos(lat2r) * cos(dLon)
        return Float(atan2(y, x))
    }
}
