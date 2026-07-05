import Foundation

enum AppTab: String, CaseIterable, Hashable {
    case home = "Home"
    case events = "Events"
    case matches = "Matches"
    case profile = "Profile"

    var systemImage: String {
        switch self {
        case .home:    return "dot.radiowaves.left.and.right"
        case .events:  return "mappin.and.ellipse"
        case .matches: return "bubble.left.and.bubble.right"
        case .profile: return "person.crop.circle"
        }
    }
}
