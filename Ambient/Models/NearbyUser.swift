import Foundation

enum DistanceSource: Sendable, Equatable {
    case uwb        // NearbyInteraction — precise ±0.1m (only inside a Room)
    case ble        // BLE RSSI-derived — approximate ("~")
    case unknown    // listed on server radar but no RSSI hit yet
}

// Radar blip shown on the Home radar. Sourced from EventRadarUserDTO (identity)
// combined with a BLE RSSI hit correlated via radarToken (approximate distance).
struct NearbyUser: Sendable, Identifiable, Equatable {
    let id: UUID              // userID
    var nickname: String
    var age: Int
    var distance: Float       // meters; only meaningful when hasRealPosition == true
    var direction: Float?     // azimuth radians (device-frame); nil = unknown
    var elevation: Float?     // elevation radians (UWB only); nil otherwise
    var isOpen: Bool = true
    var hasRealPosition: Bool = true
    var distanceSource: DistanceSource = .ble

    var displayLabel: String { "\(nickname), \(age)" }
}
