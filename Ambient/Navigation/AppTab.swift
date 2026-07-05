import Foundation

enum AppTab: String, CaseIterable, Hashable {
    case home = "Home"
<<<<<<< HEAD
    case venues = "Venues"
    case activity = "Activity"
=======
    case events = "Events"
    case matches = "Matches"
>>>>>>> c5f4022 (Iniatial Commit)
    case profile = "Profile"

    var systemImage: String {
        switch self {
<<<<<<< HEAD
        case .home:     return "dot.radiowaves.left.and.right"
        case .venues:   return "mappin.and.ellipse"
        case .activity: return "bell"
        case .profile:  return "person.crop.circle"
=======
        case .home:    return "dot.radiowaves.left.and.right"
        case .events:  return "mappin.and.ellipse"
        case .matches: return "bubble.left.and.bubble.right"
        case .profile: return "person.crop.circle"
>>>>>>> c5f4022 (Iniatial Commit)
        }
    }
}
