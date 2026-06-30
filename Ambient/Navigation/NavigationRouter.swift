import SwiftUI
import Observation

@Observable
final class NavigationRouter: @unchecked Sendable {
    // @unchecked Sendable: NavigationPath is not Sendable, but this router is
    // only ever created and accessed on the MainActor (each tab owns one instance).
    var path = NavigationPath()

    func push<R: Hashable>(_ route: R) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
