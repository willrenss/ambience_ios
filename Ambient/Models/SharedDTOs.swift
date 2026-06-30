import Foundation

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

    var id: UUID { userID }
}

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
}
