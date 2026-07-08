import Foundation

// Radar blip shown on the Home radar. Position is GPS-derived via WebSocket.
struct NearbyUser: Sendable, Identifiable, Equatable {
    let id: UUID              // userID
    var nickname: String
    var age: Int
    var photoURL: String? = nil
    var interests: [String]? = nil
    var status: String? = nil
    var distance: Float       // meters from own GPS position; 0 when locating
    var direction: Float?     // bearing radians relative to device heading; nil = unknown
    var hasRealPosition: Bool = true   // false = peer GPS not received yet

    var displayLabel: String { "\(nickname), \(age)" }

    var distanceLabel: String {
        guard hasRealPosition, distance > 0 else { return "Locating…" }
        if distance < 1000 { return "~\(Int(distance.rounded()))m" }
        return String(format: "~%.1fkm", distance / 1000)
    }
}
