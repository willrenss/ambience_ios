import Foundation

struct UserProfile: Sendable, Identifiable, Codable {
    let id: UUID
<<<<<<< HEAD
    var displayName: String
=======
    var nickname: String

    // Kept for UI that still references displayName during migration.
    var displayName: String { nickname }
>>>>>>> c5f4022 (Iniatial Commit)
}
