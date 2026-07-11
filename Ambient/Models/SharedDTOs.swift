//import Foundation
//
//// MARK: - Auth
//
//struct AuthResponse: Sendable {
//    let token: String
//    let userID: UUID
//    let nickname: String
//    let secretKey: String?   // returned ONLY at signup — persist immediately
//}
//
//extension AuthResponse: Decodable {
//    private enum CodingKeys: CodingKey { case token, userID, nickname, secretKey }
//    nonisolated init(from decoder: any Decoder) throws {
//        let c = try decoder.container(keyedBy: CodingKeys.self)
//        token     = try c.decode(String.self, forKey: .token)
//        userID    = try c.decode(UUID.self,   forKey: .userID)
//        nickname  = try c.decode(String.self, forKey: .nickname)
//        secretKey = try c.decodeIfPresent(String.self, forKey: .secretKey)
//    }
//}
//
//// MARK: - Interests
//
//struct Interest: Sendable, Identifiable, Hashable {
//    let id: UUID
//    let name: String
//}
//
//extension Interest: Codable {
//    private enum CodingKeys: CodingKey { case id, name }
//    nonisolated init(from decoder: any Decoder) throws {
//        let c = try decoder.container(keyedBy: CodingKeys.self)
//        id   = try c.decode(UUID.self,   forKey: .id)
//        name = try c.decode(String.self, forKey: .name)
//    }
//    nonisolated func encode(to encoder: any Encoder) throws {
//        var c = encoder.container(keyedBy: CodingKeys.self)
//        try c.encode(id,   forKey: .id)
//        try c.encode(name, forKey: .name)
//    }
//}
//
//// MARK: - Events
//
//struct EventDTO: Sendable, Identifiable, Equatable {
//    let id: UUID
//    let name: String
//    let longitude: Double
//    let latitude: Double
//    let deskripsi: String?
//    let linkMaps: String?
//    let linkRegistrasi: String?
//    let hargaTiket: Double?
//    let startAt: Date?
//    let endAt: Date?
//    let imageURL: String?
//    let category: String?
//    let locationName: String?
//    let attendeeInitials: [String]
//    let attendeeCount: Int
//}
//
//extension EventDTO: Codable {
//    private enum CodingKeys: String, CodingKey {
//        case id, name, longitude, latitude, deskripsi, linkMaps, linkRegistrasi,
//             hargaTiket, startAt, endAt, imageURL, category, locationName,
//             attendeeInitials, attendeeCount
//    }
//    nonisolated init(from decoder: any Decoder) throws {
//        let c = try decoder.container(keyedBy: CodingKeys.self)
//        id               = try c.decode(UUID.self,    forKey: .id)
//        name             = try c.decode(String.self,  forKey: .name)
//        longitude        = try c.decode(Double.self,  forKey: .longitude)
//        latitude         = try c.decode(Double.self,  forKey: .latitude)
//        deskripsi        = try c.decodeIfPresent(String.self, forKey: .deskripsi)
//        linkMaps         = try c.decodeIfPresent(String.self, forKey: .linkMaps)
//        linkRegistrasi   = try c.decodeIfPresent(String.self, forKey: .linkRegistrasi)
//        hargaTiket       = try c.decodeIfPresent(Double.self, forKey: .hargaTiket)
//        startAt          = try c.decodeIfPresent(Date.self,   forKey: .startAt)
//        endAt            = try c.decodeIfPresent(Date.self,   forKey: .endAt)
//        imageURL         = try c.decodeIfPresent(String.self, forKey: .imageURL)
//        category         = try c.decodeIfPresent(String.self, forKey: .category)
//        locationName     = try c.decodeIfPresent(String.self, forKey: .locationName)
//        attendeeInitials = try c.decodeIfPresent([String].self, forKey: .attendeeInitials) ?? []
//        attendeeCount    = try c.decodeIfPresent(Int.self, forKey: .attendeeCount) ?? 0
//    }
//    nonisolated func encode(to encoder: any Encoder) throws {
//        var c = encoder.container(keyedBy: CodingKeys.self)
//        try c.encode(id,             forKey: .id)
//        try c.encode(name,           forKey: .name)
//        try c.encode(longitude,      forKey: .longitude)
//        try c.encode(latitude,       forKey: .latitude)
//        try c.encodeIfPresent(deskripsi,      forKey: .deskripsi)
//        try c.encodeIfPresent(linkMaps,       forKey: .linkMaps)
//        try c.encodeIfPresent(linkRegistrasi, forKey: .linkRegistrasi)
//        try c.encodeIfPresent(hargaTiket,     forKey: .hargaTiket)
//        try c.encodeIfPresent(startAt,        forKey: .startAt)
//        try c.encodeIfPresent(endAt,          forKey: .endAt)
//        try c.encodeIfPresent(imageURL,       forKey: .imageURL)
//        try c.encodeIfPresent(category,       forKey: .category)
//        try c.encodeIfPresent(locationName,   forKey: .locationName)
//        try c.encode(attendeeInitials, forKey: .attendeeInitials)
//        try c.encode(attendeeCount,    forKey: .attendeeCount)
//    }
//}
//
//struct JoinEventResponse: Sendable {
//    let radarEligible: Bool
//    let distanceMeters: Double
//    let radiusMeters: Double   // always 500
//}
//
//extension JoinEventResponse: Codable {
//    private enum CodingKeys: CodingKey { case radarEligible, distanceMeters, radiusMeters }
//    nonisolated init(from decoder: any Decoder) throws {
//        let c = try decoder.container(keyedBy: CodingKeys.self)
//        radarEligible  = try c.decode(Bool.self,   forKey: .radarEligible)
//        distanceMeters = try c.decode(Double.self, forKey: .distanceMeters)
//        radiusMeters   = try c.decode(Double.self, forKey: .radiusMeters)
//    }
//    nonisolated func encode(to encoder: any Encoder) throws {
//        var c = encoder.container(keyedBy: CodingKeys.self)
//        try c.encode(radarEligible,  forKey: .radarEligible)
//        try c.encode(distanceMeters, forKey: .distanceMeters)
//        try c.encode(radiusMeters,   forKey: .radiusMeters)
//    }
//}
//
//// Ambient radar entry — one person currently radar-active on the same event.
//struct EventRadarUserDTO: Sendable, Identifiable {
//    let userID: UUID
//    let nickname: String
//    let age: Int
//    let radarToken: String     // short stable hex (8 bytes) embedded in BLE advertisement
//    var photoURL: String? = nil
//    var interests: [String]? = nil
//    var status: String? = nil
//    var lat: Double? = nil     // GPS latitude — pushed via WebSocket
//    var lng: Double? = nil     // GPS longitude — pushed via WebSocket
//
//    var id: UUID { userID }
//}
//
//extension EventRadarUserDTO: Codable {
//    private enum CodingKeys: CodingKey { case userID, nickname, age, radarToken, photoURL, interests, status, lat, lng }
//    nonisolated init(from decoder: any Decoder) throws {
//        let c = try decoder.container(keyedBy: CodingKeys.self)
//        userID     = try c.decode(UUID.self,   forKey: .userID)
//        nickname   = try c.decode(String.self, forKey: .nickname)
//        age        = try c.decode(Int.self,    forKey: .age)
//        radarToken = try c.decode(String.self, forKey: .radarToken)
//        photoURL   = try c.decodeIfPresent(String.self,   forKey: .photoURL)
//        interests  = try c.decodeIfPresent([String].self, forKey: .interests)
//        status     = try c.decodeIfPresent(String.self,   forKey: .status)
//        lat        = try c.decodeIfPresent(Double.self,   forKey: .lat)
//        lng        = try c.decodeIfPresent(Double.self,   forKey: .lng)
//    }
//    nonisolated func encode(to encoder: any Encoder) throws {
//        var c = encoder.container(keyedBy: CodingKeys.self)
//        try c.encode(userID,     forKey: .userID)
//        try c.encode(nickname,   forKey: .nickname)
//        try c.encode(age,        forKey: .age)
//        try c.encode(radarToken, forKey: .radarToken)
//        try c.encodeIfPresent(photoURL,  forKey: .photoURL)
//        try c.encodeIfPresent(interests, forKey: .interests)
//        try c.encodeIfPresent(status,    forKey: .status)
//        try c.encodeIfPresent(lat,       forKey: .lat)
//        try c.encodeIfPresent(lng,       forKey: .lng)
//    }
//}
//
//// MARK: - Radar WebSocket
//
//struct RadarSocketMessage: Sendable {
//    let event: String   // "roster" | "user_moved" | "ping" | "left_radius" | "location"
//    let payload: String
//}
//
//extension RadarSocketMessage: Codable {
//    private enum CodingKeys: CodingKey { case event, payload }
//    nonisolated init(from decoder: any Decoder) throws {
//        let c   = try decoder.container(keyedBy: CodingKeys.self)
//        event   = try c.decode(String.self, forKey: .event)
//        payload = try c.decode(String.self, forKey: .payload)
//    }
//    nonisolated func encode(to encoder: any Encoder) throws {
//        var c = encoder.container(keyedBy: CodingKeys.self)
//        try c.encode(event,   forKey: .event)
//        try c.encode(payload, forKey: .payload)
//    }
//}
//
//struct UserPositionUpdate: Sendable, Codable {
//    let userID: UUID
//    let lat: Double
//    let lng: Double
//}
//
//struct MutualMatchWS: Sendable, Codable {
//    let roomID: UUID
//    let peerUserID: UUID
//}
//
//// MARK: - Ping
//
//struct PingResponse: Sendable {
//    let mutual: Bool
//    let roomID: UUID?
//}
//
//extension PingResponse: Codable {
//    private enum CodingKeys: CodingKey { case mutual, roomID }
//    nonisolated init(from decoder: any Decoder) throws {
//        let c  = try decoder.container(keyedBy: CodingKeys.self)
//        mutual = try c.decode(Bool.self,        forKey: .mutual)
//        roomID = try c.decodeIfPresent(UUID.self, forKey: .roomID)
//    }
//    nonisolated func encode(to encoder: any Encoder) throws {
//        var c = encoder.container(keyedBy: CodingKeys.self)
//        try c.encode(mutual,             forKey: .mutual)
//        try c.encodeIfPresent(roomID,    forKey: .roomID)
//    }
//}
//
//struct PingNotificationDTO: Sendable, Identifiable {
//    let fromUserID: UUID
//    let fromNickname: String
//    let fromAge: Int
//    let eventID: UUID
//    let createdAt: Date
//
//    var id: UUID { fromUserID }
//}
//
//extension PingNotificationDTO: Codable {
//    private enum CodingKeys: CodingKey { case fromUserID, fromNickname, fromAge, eventID, createdAt }
//    nonisolated init(from decoder: any Decoder) throws {
//        let c        = try decoder.container(keyedBy: CodingKeys.self)
//        fromUserID   = try c.decode(UUID.self,   forKey: .fromUserID)
//        fromNickname = try c.decode(String.self, forKey: .fromNickname)
//        fromAge      = try c.decode(Int.self,    forKey: .fromAge)
//        eventID      = try c.decode(UUID.self,   forKey: .eventID)
//        createdAt    = try c.decode(Date.self,   forKey: .createdAt)
//    }
//    nonisolated func encode(to encoder: any Encoder) throws {
//        var c = encoder.container(keyedBy: CodingKeys.self)
//        try c.encode(fromUserID,   forKey: .fromUserID)
//        try c.encode(fromNickname, forKey: .fromNickname)
//        try c.encode(fromAge,      forKey: .fromAge)
//        try c.encode(eventID,      forKey: .eventID)
//        try c.encode(createdAt,    forKey: .createdAt)
//    }
//}
//
//// MARK: - Matches / Rooms
//
//struct RoomDTO: Sendable, Identifiable {
//    let id: UUID
//    let codeRoom: String
//    let peerUserID: UUID
//    let peerNickname: String
//    let peerAge: Int
//    let eventID: UUID?
//    let eventName: String?
//    let createdAt: Date?
//    /// true = current user was the first pinger (userA) → UWB guest/initiator
//    let isInitiator: Bool
//}
//
//extension RoomDTO: Codable {
//    private enum CodingKeys: CodingKey {
//        case id, codeRoom, peerUserID, peerNickname, peerAge, eventID, eventName, createdAt, isInitiator
//    }
//    nonisolated init(from decoder: any Decoder) throws {
//        let c        = try decoder.container(keyedBy: CodingKeys.self)
//        id           = try c.decode(UUID.self,   forKey: .id)
//        codeRoom     = try c.decode(String.self, forKey: .codeRoom)
//        peerUserID   = try c.decode(UUID.self,   forKey: .peerUserID)
//        peerNickname = try c.decode(String.self, forKey: .peerNickname)
//        peerAge      = try c.decode(Int.self,    forKey: .peerAge)
//        eventID      = try c.decodeIfPresent(UUID.self,   forKey: .eventID)
//        eventName    = try c.decodeIfPresent(String.self, forKey: .eventName)
//        createdAt    = try c.decodeIfPresent(Date.self,   forKey: .createdAt)
//        isInitiator  = try c.decodeIfPresent(Bool.self,   forKey: .isInitiator) ?? false
//    }
//    nonisolated func encode(to encoder: any Encoder) throws {
//        var c = encoder.container(keyedBy: CodingKeys.self)
//        try c.encode(id,           forKey: .id)
//        try c.encode(codeRoom,     forKey: .codeRoom)
//        try c.encode(peerUserID,   forKey: .peerUserID)
//        try c.encode(peerNickname, forKey: .peerNickname)
//        try c.encode(peerAge,      forKey: .peerAge)
//        try c.encodeIfPresent(eventID,   forKey: .eventID)
//        try c.encodeIfPresent(eventName, forKey: .eventName)
//        try c.encodeIfPresent(createdAt, forKey: .createdAt)
//        try c.encode(isInitiator, forKey: .isInitiator)
//    }
//}
//
//struct ChatMessageDTO: Sendable, Identifiable {
//    let id: UUID
//    let roomID: UUID
//    let senderUserID: UUID
//    let message: String
//    let timestamp: Date
//}
//
//extension ChatMessageDTO: Codable {
//    private enum CodingKeys: CodingKey { case id, roomID, senderUserID, message, timestamp }
//    nonisolated init(from decoder: any Decoder) throws {
//        let c        = try decoder.container(keyedBy: CodingKeys.self)
//        id           = try c.decode(UUID.self,   forKey: .id)
//        roomID       = try c.decode(UUID.self,   forKey: .roomID)
//        senderUserID = try c.decode(UUID.self,   forKey: .senderUserID)
//        message      = try c.decode(String.self, forKey: .message)
//        timestamp    = try c.decode(Date.self,   forKey: .timestamp)
//    }
//    nonisolated func encode(to encoder: any Encoder) throws {
//        var c = encoder.container(keyedBy: CodingKeys.self)
//        try c.encode(id,           forKey: .id)
//        try c.encode(roomID,       forKey: .roomID)
//        try c.encode(senderUserID, forKey: .senderUserID)
//        try c.encode(message,      forKey: .message)
//        try c.encode(timestamp,    forKey: .timestamp)
//    }
//}
//
//// MARK: - WebSocket
//
//struct RoomSocketMessage: Sendable {
//    let event: String   // "chatMessage" | "discoveryToken" | "peerConnected" | "peerDisconnected"
//    let payload: String
//}
//
//extension RoomSocketMessage: Codable {
//    private enum CodingKeys: CodingKey { case event, payload }
//    nonisolated init(from decoder: any Decoder) throws {
//        let c   = try decoder.container(keyedBy: CodingKeys.self)
//        event   = try c.decode(String.self, forKey: .event)
//        payload = try c.decode(String.self, forKey: .payload)
//    }
//    nonisolated func encode(to encoder: any Encoder) throws {
//        var c = encoder.container(keyedBy: CodingKeys.self)
//        try c.encode(event,   forKey: .event)
//        try c.encode(payload, forKey: .payload)
//    }
//}

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

// A single avatar-stack entry — a real photo when the user has one, with
// `initial` as the fallback letter, matching the photo-or-initials pattern
// used everywhere else in the app.
struct EventAttendeePreviewDTO: Sendable, Equatable, Codable {
    let photoURL: String?
    let initial: String
}

struct EventDTO: Sendable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let source: String?          // Ditambahkan untuk membedakan loket, yesplis, artatix
    let organizer: String?       // Ditambahkan untuk nama penyelenggara
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
    // Who's currently online (radar-active) at this event — checked-in card.
    var onlineAttendees: [EventAttendeePreviewDTO] = []
    var onlineCount: Int = 0
    // Who's bookmarked this event — preview (not-checked-in) card. `var` so the
    // heart button can update these optimistically without a round-trip.
    var bookmarkAttendees: [EventAttendeePreviewDTO] = []
    var bookmarkCount: Int = 0
    var isBookmarked: Bool = false
}

extension EventDTO: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, source, organizer, longitude, latitude, deskripsi, linkMaps, linkRegistrasi,
             hargaTiket, startAt, endAt, imageURL, category, locationName,
             attendeeInitials, attendeeCount,
             onlineAttendees, onlineCount, bookmarkAttendees, bookmarkCount, isBookmarked
    }
    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(UUID.self,    forKey: .id)
        name             = try c.decode(String.self,  forKey: .name)
        source           = try c.decodeIfPresent(String.self, forKey: .source)
        organizer        = try c.decodeIfPresent(String.self, forKey: .organizer)
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
        onlineAttendees  = try c.decodeIfPresent([EventAttendeePreviewDTO].self, forKey: .onlineAttendees) ?? []
        onlineCount      = try c.decodeIfPresent(Int.self, forKey: .onlineCount) ?? 0
        bookmarkAttendees = try c.decodeIfPresent([EventAttendeePreviewDTO].self, forKey: .bookmarkAttendees) ?? []
        bookmarkCount    = try c.decodeIfPresent(Int.self, forKey: .bookmarkCount) ?? 0
        isBookmarked     = try c.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,             forKey: .id)
        try c.encode(name,           forKey: .name)
        try c.encodeIfPresent(source,         forKey: .source)
        try c.encodeIfPresent(organizer,      forKey: .organizer)
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
        try c.encode(onlineAttendees,  forKey: .onlineAttendees)
        try c.encode(onlineCount,      forKey: .onlineCount)
        try c.encode(bookmarkAttendees, forKey: .bookmarkAttendees)
        try c.encode(bookmarkCount,    forKey: .bookmarkCount)
        try c.encode(isBookmarked,     forKey: .isBookmarked)
    }
}

struct JoinEventResponse: Sendable {
    let radarEligible: Bool
    let distanceMeters: Double
    let radiusMeters: Double
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

// Ambient radar entry
struct EventRadarUserDTO: Sendable, Identifiable {
    let userID: UUID
    let nickname: String
    let age: Int
    let radarToken: String
    var photoURL: String? = nil
    var interests: [String]? = nil
    var status: String? = nil
    var lat: Double? = nil
    var lng: Double? = nil

    var id: UUID { userID }
}

extension EventRadarUserDTO: Codable {
    private enum CodingKeys: CodingKey { case userID, nickname, age, radarToken, photoURL, interests, status, lat, lng }
    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID     = try c.decode(UUID.self,   forKey: .userID)
        nickname   = try c.decode(String.self, forKey: .nickname)
        age        = try c.decode(Int.self,    forKey: .age)
        radarToken = try c.decode(String.self, forKey: .radarToken)
        photoURL   = try c.decodeIfPresent(String.self,   forKey: .photoURL)
        interests  = try c.decodeIfPresent([String].self, forKey: .interests)
        status     = try c.decodeIfPresent(String.self,   forKey: .status)
        lat        = try c.decodeIfPresent(Double.self,   forKey: .lat)
        lng        = try c.decodeIfPresent(Double.self,   forKey: .lng)
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(userID,     forKey: .userID)
        try c.encode(nickname,   forKey: .nickname)
        try c.encode(age,        forKey: .age)
        try c.encode(radarToken, forKey: .radarToken)
        try c.encodeIfPresent(photoURL,  forKey: .photoURL)
        try c.encodeIfPresent(interests, forKey: .interests)
        try c.encodeIfPresent(status,    forKey: .status)
        try c.encodeIfPresent(lat,       forKey: .lat)
        try c.encodeIfPresent(lng,       forKey: .lng)
    }
}

struct RadarSocketMessage: Sendable {
    let event: String
    let payload: String
}

extension RadarSocketMessage: Codable {
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

struct UserPositionUpdate: Sendable, Codable {
    let userID: UUID
    let lat: Double
    let lng: Double
}

struct MutualMatchWS: Sendable, Codable {
    let roomID: UUID
    let peerUserID: UUID
}

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
    let fromPhotoURL: String?
    let eventID: UUID
    let createdAt: Date

    var id: UUID { fromUserID }
}

extension PingNotificationDTO: Codable {
    private enum CodingKeys: CodingKey { case fromUserID, fromNickname, fromAge, fromPhotoURL, eventID, createdAt }
    nonisolated init(from decoder: any Decoder) throws {
        let c        = try decoder.container(keyedBy: CodingKeys.self)
        fromUserID   = try c.decode(UUID.self,   forKey: .fromUserID)
        fromNickname = try c.decode(String.self, forKey: .fromNickname)
        fromAge      = try c.decode(Int.self,    forKey: .fromAge)
        fromPhotoURL = try c.decodeIfPresent(String.self, forKey: .fromPhotoURL)
        eventID      = try c.decode(UUID.self,   forKey: .eventID)
        createdAt    = try c.decode(Date.self,   forKey: .createdAt)
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(fromUserID,   forKey: .fromUserID)
        try c.encode(fromNickname, forKey: .fromNickname)
        try c.encode(fromAge,      forKey: .fromAge)
        try c.encodeIfPresent(fromPhotoURL, forKey: .fromPhotoURL)
        try c.encode(eventID,      forKey: .eventID)
        try c.encode(createdAt,    forKey: .createdAt)
    }
}

struct RoomDTO: Sendable, Identifiable {
    let id: UUID
    let codeRoom: String
    let peerUserID: UUID
    let peerNickname: String
    let peerAge: Int
    let peerPhotoURL: String?
    let eventID: UUID?
    let eventName: String?
    let createdAt: Date?
    let updatedAt: Date?
    /// Who sent the most recent chat message (nil if no messages yet) — lets the
    /// client tell "peer sent a new message" apart from "I sent the last one".
    let lastMessageSenderID: UUID?
    /// Preview text of the most recent chat message (nil if no messages yet).
    let lastMessageText: String?
    /// true = current user was the first pinger (userA) → UWB guest/initiator
    let isInitiator: Bool
}

extension RoomDTO: Codable {
    private enum CodingKeys: CodingKey {
        case id, codeRoom, peerUserID, peerNickname, peerAge, peerPhotoURL, eventID, eventName, createdAt, updatedAt, lastMessageSenderID, lastMessageText, isInitiator
    }
    nonisolated init(from decoder: any Decoder) throws {
        let c        = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(UUID.self,   forKey: .id)
        codeRoom     = try c.decode(String.self, forKey: .codeRoom)
        peerUserID   = try c.decode(UUID.self,   forKey: .peerUserID)
        peerNickname = try c.decode(String.self, forKey: .peerNickname)
        peerAge      = try c.decode(Int.self,    forKey: .peerAge)
        peerPhotoURL = try c.decodeIfPresent(String.self, forKey: .peerPhotoURL)
        eventID      = try c.decodeIfPresent(UUID.self,   forKey: .eventID)
        eventName    = try c.decodeIfPresent(String.self, forKey: .eventName)
        createdAt    = try c.decodeIfPresent(Date.self,   forKey: .createdAt)
        updatedAt    = try c.decodeIfPresent(Date.self,   forKey: .updatedAt)
        lastMessageSenderID = try c.decodeIfPresent(UUID.self, forKey: .lastMessageSenderID)
        lastMessageText = try c.decodeIfPresent(String.self, forKey: .lastMessageText)
        isInitiator  = try c.decodeIfPresent(Bool.self,   forKey: .isInitiator) ?? false
    }
    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,           forKey: .id)
        try c.encode(codeRoom,     forKey: .codeRoom)
        try c.encode(peerUserID,   forKey: .peerUserID)
        try c.encode(peerNickname, forKey: .peerNickname)
        try c.encode(peerAge,      forKey: .peerAge)
        try c.encodeIfPresent(peerPhotoURL, forKey: .peerPhotoURL)
        try c.encodeIfPresent(eventID,   forKey: .eventID)
        try c.encodeIfPresent(eventName, forKey: .eventName)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(lastMessageSenderID, forKey: .lastMessageSenderID)
        try c.encodeIfPresent(lastMessageText, forKey: .lastMessageText)
        try c.encode(isInitiator, forKey: .isInitiator)
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

struct RoomSocketMessage: Sendable {
    let event: String
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

