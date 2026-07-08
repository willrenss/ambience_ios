import Foundation

struct UserProfile: Sendable, Identifiable, Codable {
    let id: UUID
    var nickname: String
    var age: Int? = nil
    var birthdate: Date? = nil
    var hometown: String? = nil
    var interests: [String]? = nil
    var photoURL: String? = nil

    var displayName: String { nickname }

    var generation: String? {
        guard let age else { return nil }
        let birthYear = Calendar.current.component(.year, from: .now) - age
        switch birthYear {
        case ...1945: return "Silent"
        case 1946...1964: return "Boomer"
        case 1965...1980: return "Gen X"
        case 1981...1996: return "Millennial"
        case 1997...2012: return "Gen Z"
        default: return "Gen Alpha"
        }
    }

    var formattedBirthdate: String? {
        guard let birthdate else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: birthdate)
    }
}
