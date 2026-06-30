import CoreLocation
import Foundation

private let isOpenKey = "ambsocial_is_open"

actor LocationService: NSObject {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private var locationDelegate: LocationDelegate?
    private(set) var currentLocation: CLLocation?
    private(set) var headingDegrees: Double?

    override init() { super.init() }

    func requestPermissionAndStart() {
        let delegate = LocationDelegate(owner: self)
        locationDelegate = delegate
        manager.delegate = delegate
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
        if let cached = manager.location {
            Task { await didUpdateLocation(cached) }
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        currentLocation = nil
        headingDegrees = nil
    }

    func didUpdateLocation(_ location: CLLocation) {
        guard location.horizontalAccuracy > 0 else { return }
        currentLocation = location
        Task {
            let isOpen = await MainActor.run { UserDefaults.standard.bool(forKey: isOpenKey) }
            if isOpen { await ServerProximityService.shared.updatePresence(isOpen: true) }
        }
    }

    func didUpdateHeading(_ degrees: Double) {
        headingDegrees = degrees
        Task { await ServerProximityService.shared.updateHeading(degrees) }
    }

    @MainActor static func setIsOpen(_ open: Bool) {
        UserDefaults.standard.set(open, forKey: isOpenKey)
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
