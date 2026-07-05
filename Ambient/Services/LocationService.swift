import CoreLocation
import Foundation

<<<<<<< HEAD
private let isOpenKey = "ambsocial_is_open"

=======
>>>>>>> c5f4022 (Iniatial Commit)
actor LocationService: NSObject {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private var locationDelegate: LocationDelegate?
    private(set) var currentLocation: CLLocation?
    private(set) var headingDegrees: Double?

<<<<<<< HEAD
=======
    // Continuation stream of fresh CLLocation fixes — consumed by EventRadarService's heartbeat.
    private var locationContinuation: AsyncStream<CLLocation>.Continuation?

>>>>>>> c5f4022 (Iniatial Commit)
    override init() { super.init() }

    func requestPermissionAndStart() {
        let delegate = LocationDelegate(owner: self)
        locationDelegate = delegate
        manager.delegate = delegate
<<<<<<< HEAD
        // HundredMeters fires immediately using WiFi/cell positioning indoors.
        // kCLLocationAccuracyBest waits for satellite GPS which may never arrive inside.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 10   // only trigger update if moved 10+ meters
        manager.headingFilter = 2
        // Only enable background location if the capability is declared in the app bundle.
        // Setting this without UIBackgroundModes → location causes a runtime crash.
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        if backgroundModes.contains("location") {
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = false
            manager.requestAlwaysAuthorization()
        } else {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
        // Seed from OS-cached location immediately — avoids "no fix" on first open
        // while waiting for a fresh update from the delegate.
=======
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter  = kCLDistanceFilterNone
        manager.headingFilter   = 2
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
>>>>>>> c5f4022 (Iniatial Commit)
        if let cached = manager.location {
            Task { await didUpdateLocation(cached) }
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        currentLocation = nil
        headingDegrees = nil
<<<<<<< HEAD
=======
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
>>>>>>> c5f4022 (Iniatial Commit)
    }

    func didUpdateLocation(_ location: CLLocation) {
        guard location.horizontalAccuracy > 0 else { return }
        currentLocation = location
<<<<<<< HEAD
        Task {
            let isOpen = await MainActor.run { UserDefaults.standard.bool(forKey: isOpenKey) }
            if isOpen { await ServerProximityService.shared.updatePresence(isOpen: true) }
        }
=======
        locationContinuation?.yield(location)
>>>>>>> c5f4022 (Iniatial Commit)
    }

    func didUpdateHeading(_ degrees: Double) {
        headingDegrees = degrees
<<<<<<< HEAD
        Task { await ServerProximityService.shared.updateHeading(degrees) }
    }

    @MainActor static func setIsOpen(_ open: Bool) {
        UserDefaults.standard.set(open, forKey: isOpenKey)
=======
>>>>>>> c5f4022 (Iniatial Commit)
    }
}

private final class LocationDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private weak var owner: LocationService?
<<<<<<< HEAD

=======
>>>>>>> c5f4022 (Iniatial Commit)
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
