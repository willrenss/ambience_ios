import Observation
import Foundation
import CoreLocation

private struct EmptyBody: Encodable {}

@Observable
@MainActor
final class HomeViewModel {
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
}
