import Foundation

enum AppTab: String, CaseIterable, Hashable {
    case maps      = "Maps"
    case bookmarks = "Bookmarks"
    case profile   = "Profile"

    var systemImage: String {
        switch self {
        case .maps:      return "map.fill"
        case .bookmarks: return "bookmark.fill"
        case .profile:   return "person.fill"
        }
    }
}
