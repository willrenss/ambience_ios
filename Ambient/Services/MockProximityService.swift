import Foundation

/// No-op proximity service used in Simulator.
/// Emits no nearby users — radar stays empty until real BLE/UWB hardware is available.
actor MockProximityService: ProximityServiceProtocol {
    private(set) var nearbyUsersStream: AsyncStream<[NearbyUser]>
    private var streamContinuation: AsyncStream<[NearbyUser]>.Continuation?

    init() {
        var cont: AsyncStream<[NearbyUser]>.Continuation?
        nearbyUsersStream = AsyncStream { cont = $0 }
        streamContinuation = cont
    }

    func startScanning() async throws {
        streamContinuation?.yield([])
    }

    func stopScanning() async {
        streamContinuation?.yield([])
    }
}
