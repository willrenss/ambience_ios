import Foundation

<<<<<<< HEAD
struct VenueDTO: Codable, Sendable, Identifiable {
    var id: UUID
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
}

struct RoomDTO: Codable, Sendable, Identifiable {
    var id: UUID
    var venueID: UUID
    var createdByUserID: UUID
    var status: String
    var memberCount: Int
    var createdAt: Date
}

struct RoomMemberDTO: Codable, Sendable, Identifiable {
    var userID: UUID
    var displayName: String
    var joinedAt: Date
=======
// MARK: - Auth

struct AuthResponse: Decodable, Sendable {
    let token: String
    let userID: UUID
    let nickname: String
    let secretKey: String?   // returned ONLY at signup — persist immediately
}

// MARK: - Interests

struct Interest: Codable, Sendable, Identifiable, Hashable {
    let id: UUID
    let name: String
}

// MARK: - Events

struct EventDTO: Codable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let longitude: Double
    let latitude: Double
    let deskripsi: String?
    let linkMaps: String?
    let linkRegistrasi: String?
    let hargaTiket: Double?
    let startAt: Date?
    let endAt: Date?
    let imageURL: String?
    let category: String?
    let locationName: String?
    let attendeeInitials: [String]
    let attendeeCount: Int
}

struct JoinEventResponse: Codable, Sendable {
    let radarEligible: Bool
    let distanceMeters: Double
    let radiusMeters: Double   // always 500
}

// Ambient radar entry — one person currently radar-active on the same event.
struct EventRadarUserDTO: Codable, Sendable, Identifiable {
    let userID: UUID
    let nickname: String
    let age: Int
    let radarToken: String     // short stable hex (8 bytes) embedded in BLE advertisement
>>>>>>> c5f4022 (Iniatial Commit)

    var id: UUID { userID }
}

<<<<<<< HEAD
struct JoinRequestDTO: Codable, Sendable, Identifiable {
    var id: UUID
    var roomID: UUID
    var status: String   // "pending", "approved", "expired"
    var createdAt: Date
    var expiresAt: Date

    var displayStatus: String {
        switch status {
        case "pending":  return "Pending"
        case "approved": return "Approved"
        default:         return "Request expired"
        }
    }
}

struct MatchDTO: Codable, Sendable, Identifiable {
    var id: UUID
    var userAID: UUID
    var userBID: UUID
    var venueID: UUID
    var matchedAt: Date
}

struct RoomStateDTO: Codable, Sendable {
    var roomID: UUID
    var members: [RoomMemberDTO]
    var pendingRequests: Int
}

struct RoomSocketMessage: Codable, Sendable {
    var event: String
    var payload: String
=======
// MARK: - Ping

struct PingResponse: Codable, Sendable {
    let mutual: Bool
    let roomID: UUID?
}

struct PingNotificationDTO: Codable, Sendable, Identifiable {
    let fromUserID: UUID
    let fromNickname: String
    let fromAge: Int
    let eventID: UUID
    let createdAt: Date

    var id: UUID { fromUserID }
}

// MARK: - Matches / Rooms

struct RoomDTO: Codable, Sendable, Identifiable {
    let id: UUID
    let codeRoom: String
    let peerUserID: UUID
    let peerNickname: String
    let peerAge: Int
    let eventID: UUID?
    let eventName: String?
    let createdAt: Date?
}

struct ChatMessageDTO: Codable, Sendable, Identifiable {
    let id: UUID
    let roomID: UUID
    let senderUserID: UUID
    let message: String
    let timestamp: Date
}

// MARK: - WebSocket

struct RoomSocketMessage: Codable, Sendable {
    let event: String   // "chatMessage" | "discoveryToken" | "peerConnected" | "peerDisconnected"
    let payload: String
>>>>>>> c5f4022 (Iniatial Commit)
}
