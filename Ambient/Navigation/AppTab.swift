import Foundation

enum AppTab: String, CaseIterable, Hashable {
    case home = "Home"
    case venues = "Venues"
    case activity = "Activity"
    case profile = "Profile"

    var systemImage: String {
        switch self {
        case .home:     return "dot.radiowaves.left.and.right"
        case .venues:   return "mappin.and.ellipse"
        case .activity: return "bell"
        case .profile:  return "person.crop.circle"
        }
    }
}
