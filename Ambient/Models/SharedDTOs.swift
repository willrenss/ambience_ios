import Foundation

// MARK: - Auth

struct AuthResponse: Sendable {
    let token: String
    let userID: UUID
    let nickname: String
    let secretKey: String?   // returned ONLY at signup — persist immediately
}

extension AuthResponse: Decodable {
    private enum CodingKeys: CodingKey { case token, userID, nickname, secretKey }
    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        token     = try c.decode(String.self, forKey: .token)
        userID    = try c.decode(UUID.self,   forKey: .userID)
        nickname  = try c.decode(String.self, forKey: .nickname)
        secretKey = try c.decodeIfPresent(String.self, forKey: .secretKey)
    }
}

// MARK: - Interests

struct Interest: Sendable, Identifiable, Hashable {
    let id: UUID
    let name: String
}

extension Interest: Codable {
    private enum CodingKeys: CodingKey { case id, name }
    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id   = try c.decode(UUID.self,   forKey: .id)
        name = try c.decode(String.self, forKey: .name)
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,   forKey: .id)
        try c.encode(name, forKey: .name)
    }
}

// MARK: - Events

struct EventDTO: Sendable, Identifiable, Equatable {
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

extension EventDTO: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, longitude, latitude, deskripsi, linkMaps, linkRegistrasi,
             hargaTiket, startAt, endAt, imageURL, category, locationName,
             attendeeInitials, attendeeCount
    }
    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(UUID.self,    forKey: .id)
        name             = try c.decode(String.self,  forKey: .name)
        longitude        = try c.decode(Double.self,  forKey: .longitude)
        latitude         = try c.decode(Double.self,  forKey: .latitude)
        deskripsi        = try c.decodeIfPresent(String.self, forKey: .deskripsi)
        linkMaps         = try c.decodeIfPresent(String.self, forKey: .linkMaps)
        linkRegistrasi   = try c.decodeIfPresent(String.self, forKey: .linkRegistrasi)
        hargaTiket       = try c.decodeIfPresent(Double.self, forKey: .hargaTiket)
        startAt          = try c.decodeIfPresent(Date.self,   forKey: .startAt)
        endAt            = try c.decodeIfPresent(Date.self,   forKey: .endAt)
        imageURL         = try c.decodeIfPresent(String.self, forKey: .imageURL)
        category         = try c.decodeIfPresent(String.self, forKey: .category)
        locationName     = try c.decodeIfPresent(String.self, forKey: .locationName)
        attendeeInitials = try c.decodeIfPresent([String].self, forKey: .attendeeInitials) ?? []
        attendeeCount    = try c.decodeIfPresent(Int.self, forKey: .attendeeCount) ?? 0
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,             forKey: .id)
        try c.encode(name,           forKey: .name)
        try c.encode(longitude,      forKey: .longitude)
        try c.encode(latitude,       forKey: .latitude)
        try c.encodeIfPresent(deskripsi,      forKey: .deskripsi)
        try c.encodeIfPresent(linkMaps,       forKey: .linkMaps)
        try c.encodeIfPresent(linkRegistrasi, forKey: .linkRegistrasi)
        try c.encodeIfPresent(hargaTiket,     forKey: .hargaTiket)
        try c.encodeIfPresent(startAt,        forKey: .startAt)
        try c.encodeIfPresent(endAt,          forKey: .endAt)
        try c.encodeIfPresent(imageURL,       forKey: .imageURL)
        try c.encodeIfPresent(category,       forKey: .category)
        try c.encodeIfPresent(locationName,   forKey: .locationName)
        try c.encode(attendeeInitials, forKey: .attendeeInitials)
        try c.encode(attendeeCount,    forKey: .attendeeCount)
    }
}

struct JoinEventResponse: Sendable {
    let radarEligible: Bool
    let distanceMeters: Double
    let radiusMeters: Double   // always 500
}

extension JoinEventResponse: Codable {
    private enum CodingKeys: CodingKey { case radarEligible, distanceMeters, radiusMeters }
    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        radarEligible  = try c.decode(Bool.self,   forKey: .radarEligible)
        distanceMeters = try c.decode(Double.self, forKey: .distanceMeters)
        radiusMeters   = try c.decode(Double.self, forKey: .radiusMeters)
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(radarEligible,  forKey: .radarEligible)
        try c.encode(distanceMeters, forKey: .distanceMeters)
        try c.encode(radiusMeters,   forKey: .radiusMeters)
    }
}

// Ambient radar entry — one person currently radar-active on the same event.
struct EventRadarUserDTO: Sendable, Identifiable {
    let userID: UUID
    let nickname: String
    let age: Int
    let radarToken: String     // short stable hex (8 bytes) embedded in BLE advertisement

    var id: UUID { userID }
}

extension EventRadarUserDTO: Codable {
    private enum CodingKeys: CodingKey { case userID, nickname, age, radarToken }
    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID     = try c.decode(UUID.self,   forKey: .userID)
        nickname   = try c.decode(String.self, forKey: .nickname)
        age        = try c.decode(Int.self,    forKey: .age)
        radarToken = try c.decode(String.self, forKey: .radarToken)
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(userID,     forKey: .userID)
        try c.encode(nickname,   forKey: .nickname)
        try c.encode(age,        forKey: .age)
        try c.encode(radarToken, forKey: .radarToken)
    }
}

// MARK: - Ping

struct PingResponse: Sendable {
    let mutual: Bool
    let roomID: UUID?
}

extension PingResponse: Codable {
    private enum CodingKeys: CodingKey { case mutual, roomID }
    nonisolated init(from decoder: any Decoder) throws {
        let c  = try decoder.container(keyedBy: CodingKeys.self)
        mutual = try c.decode(Bool.self,        forKey: .mutual)
        roomID = try c.decodeIfPresent(UUID.self, forKey: .roomID)
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(mutual,             forKey: .mutual)
        try c.encodeIfPresent(roomID,    forKey: .roomID)
    }
}

struct PingNotificationDTO: Sendable, Identifiable {
    let fromUserID: UUID
    let fromNickname: String
    let fromAge: Int
    let eventID: UUID
    let createdAt: Date

    var id: UUID { fromUserID }
}

extension PingNotificationDTO: Codable {
    private enum CodingKeys: CodingKey { case fromUserID, fromNickname, fromAge, eventID, createdAt }
    nonisolated init(from decoder: any Decoder) throws {
        let c        = try decoder.container(keyedBy: CodingKeys.self)
        fromUserID   = try c.decode(UUID.self,   forKey: .fromUserID)
        fromNickname = try c.decode(String.self, forKey: .fromNickname)
        fromAge      = try c.decode(Int.self,    forKey: .fromAge)
        eventID      = try c.decode(UUID.self,   forKey: .eventID)
        createdAt    = try c.decode(Date.self,   forKey: .createdAt)
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(fromUserID,   forKey: .fromUserID)
        try c.encode(fromNickname, forKey: .fromNickname)
        try c.encode(fromAge,      forKey: .fromAge)
        try c.encode(eventID,      forKey: .eventID)
        try c.encode(createdAt,    forKey: .createdAt)
    }
}

// MARK: - Matches / Rooms

struct RoomDTO: Sendable, Identifiable {
    let id: UUID
    let codeRoom: String
    let peerUserID: UUID
    let peerNickname: String
    let peerAge: Int
    let eventID: UUID?
    let eventName: String?
    let createdAt: Date?
}

extension RoomDTO: Codable {
    private enum CodingKeys: CodingKey {
        case id, codeRoom, peerUserID, peerNickname, peerAge, eventID, eventName, createdAt
    }
    nonisolated init(from decoder: any Decoder) throws {
        let c        = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(UUID.self,   forKey: .id)
        codeRoom     = try c.decode(String.self, forKey: .codeRoom)
        peerUserID   = try c.decode(UUID.self,   forKey: .peerUserID)
        peerNickname = try c.decode(String.self, forKey: .peerNickname)
        peerAge      = try c.decode(Int.self,    forKey: .peerAge)
        eventID      = try c.decodeIfPresent(UUID.self,   forKey: .eventID)
        eventName    = try c.decodeIfPresent(String.self, forKey: .eventName)
        createdAt    = try c.decodeIfPresent(Date.self,   forKey: .createdAt)
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,           forKey: .id)
        try c.encode(codeRoom,     forKey: .codeRoom)
        try c.encode(peerUserID,   forKey: .peerUserID)
        try c.encode(peerNickname, forKey: .peerNickname)
        try c.encode(peerAge,      forKey: .peerAge)
        try c.encodeIfPresent(eventID,   forKey: .eventID)
        try c.encodeIfPresent(eventName, forKey: .eventName)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

struct ChatMessageDTO: Sendable, Identifiable {
    let id: UUID
    let roomID: UUID
    let senderUserID: UUID
    let message: String
    let timestamp: Date
}

extension ChatMessageDTO: Codable {
    private enum CodingKeys: CodingKey { case id, roomID, senderUserID, message, timestamp }
    nonisolated init(from decoder: any Decoder) throws {
        let c        = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(UUID.self,   forKey: .id)
        roomID       = try c.decode(UUID.self,   forKey: .roomID)
        senderUserID = try c.decode(UUID.self,   forKey: .senderUserID)
        message      = try c.decode(String.self, forKey: .message)
        timestamp    = try c.decode(Date.self,   forKey: .timestamp)
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,           forKey: .id)
        try c.encode(roomID,       forKey: .roomID)
        try c.encode(senderUserID, forKey: .senderUserID)
        try c.encode(message,      forKey: .message)
        try c.encode(timestamp,    forKey: .timestamp)
    }
}

// MARK: - WebSocket

struct RoomSocketMessage: Sendable {
    let event: String   // "chatMessage" | "discoveryToken" | "peerConnected" | "peerDisconnected"
    let payload: String
}

extension RoomSocketMessage: Codable {
    private enum CodingKeys: CodingKey { case event, payload }
    nonisolated init(from decoder: any Decoder) throws {
        let c   = try decoder.container(keyedBy: CodingKeys.self)
        event   = try c.decode(String.self, forKey: .event)
        payload = try c.decode(String.self, forKey: .payload)
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(event,   forKey: .event)
        try c.encode(payload, forKey: .payload)
    }
}
