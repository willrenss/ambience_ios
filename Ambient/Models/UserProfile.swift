import Foundation

struct UserProfile: Sendable, Identifiable, Codable {
    let id: UUID
    var nickname: String

    // Kept for UI that still references displayName during migration.
    var displayName: String { nickname }
}
