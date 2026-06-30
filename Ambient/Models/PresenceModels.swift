import Foundation

struct NearbyUserDTO: Decodable, Sendable {
    let userID: UUID
    let displayName: String
    let latitude: Double?
    let longitude: Double?
    let horizontalAccuracy: Double?
    let discoveryToken: String?
}

struct PresenceRequestBody: Encodable, Sendable {
    let isOpen: Bool
    let latitude: Double?
    let longitude: Double?
    let horizontalAccuracy: Double?  // nil = no valid GPS fix
    let discoveryToken: String?
}
