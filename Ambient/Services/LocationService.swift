import CoreLocation
import Foundation

actor LocationService: NSObject {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private var locationDelegate: LocationDelegate?
    private(set) var currentLocation: CLLocation?
    private(set) var headingDegrees: Double?

    // Continuation stream of fresh CLLocation fixes — consumed by EventRadarService's heartbeat.
    private var locationContinuation: AsyncStream<CLLocation>.Continuation?

    override init() { super.init() }

    func requestPermissionAndStart() {
        let delegate = LocationDelegate(owner: self)
        locationDelegate = delegate
        manager.delegate = delegate
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter  = kCLDistanceFilterNone
        manager.headingFilter   = 2
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
        if let cached = manager.location {
            Task { await didUpdateLocation(cached) }
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        currentLocation = nil
        headingDegrees = nil
        locationContinuation?.finish()
        locationContinuation = nil
    }

    // A stream of location fixes. Resets any prior stream.
    func locationUpdates() -> AsyncStream<CLLocation> {
        locationContinuation?.finish()
        return AsyncStream { continuation in
            self.locationContinuation = continuation
            if let loc = currentLocation { continuation.yield(loc) }
        }
    }

    // One-shot best-effort current fix (waits briefly for the first update if none yet).
    func awaitLocation(timeout: TimeInterval = 4) async -> CLLocation? {
        if let loc = currentLocation { return loc }
        requestPermissionAndStart()
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let loc = currentLocation { return loc }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return currentLocation
    }

    func didUpdateLocation(_ location: CLLocation) {
        guard location.horizontalAccuracy > 0 else { return }
        currentLocation = location
        locationContinuation?.yield(location)
    }

    func didUpdateHeading(_ degrees: Double) {
        headingDegrees = degrees
    }
}

private final class LocationDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private weak var owner: LocationService?
    init(owner: LocationService) { self.owner = owner }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, let owner else { return }
        Task { await owner.didUpdateLocation(loc) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        guard heading.headingAccuracy >= 0 else { return }
        Task { await owner?.didUpdateHeading(heading.magneticHeading) }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        default:
            break
        }
    }
}
