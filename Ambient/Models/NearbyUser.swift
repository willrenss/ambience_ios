import Foundation

enum DistanceSource: Sendable, Equatable {
    case uwb        // NearbyInteraction — precise ±0.1m
    case gps        // CLLocation — rough ±5–30m
    case unknown    // no measurement yet
}

struct NearbyUser: Sendable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var distance: Float           // meters; only valid when hasRealPosition == true
    var direction: Float?         // radians from north; nil when direction is unknown
    var isOpen: Bool
    var hasRealPosition: Bool = true
    var distanceSource: DistanceSource = .uwb
}
