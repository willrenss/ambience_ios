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

    static func generation(for age: Int) -> String {
        switch age {
        case ..<14:   return "Gen Alpha"
        case 14..<30: return "Gen Z"
        case 30..<46: return "Gen Y"
        case 46..<62: return "Gen X"
        default:      return "Boomer"
        }
    }

    var generation: String { NearbyUser.generation(for: age) }
    var displayLabel: String { "\(nickname), \(generation)" }

    var distanceLabel: String {
        guard hasRealPosition, distance > 0 else { return "Locating…" }
        if distance < 1000 { return "~\(Int(distance.rounded()))m" }
        return String(format: "~%.1fkm", distance / 1000)
    }
}
