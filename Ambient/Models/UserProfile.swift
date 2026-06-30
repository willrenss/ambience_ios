import Foundation

struct UserProfile: Sendable, Identifiable, Codable {
    let id: UUID
    var displayName: String
}
