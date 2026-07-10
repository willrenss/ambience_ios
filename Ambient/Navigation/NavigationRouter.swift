//import SwiftUI
//import Observation
//
//@Observable
//final class NavigationRouter: @unchecked Sendable {
//    var path = NavigationPath()
//    // Explicit counter — NavigationPath.isEmpty isn't reliably observed by SwiftUI
//    var depth: Int = 0
//
//    func push<R: Hashable>(_ route: R) {
//        path.append(route)
//        depth += 1
//    }
//
//    func pop() {
//        guard !path.isEmpty else { return }
//        path.removeLast()
//        depth = max(0, depth - 1)
//    }
//
//    func popToRoot() {
//        path = NavigationPath()
//        depth = 0
//    }
//}


import SwiftUI
import Observation

@Observable
@MainActor
final class NavigationRouter {

    var path = NavigationPath()

    var depth: Int {
        path.count
    }

    func push<T: Hashable>(_ value: T) {
        path.append(value)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
