import Observation
import Foundation

@Observable
final class AppState: @unchecked Sendable {
    // @unchecked Sendable: AppState is only mutated on MainActor in practice;
    // @Observable synthesis does not currently add Sendable conformance automatically.
    var currentUser: UserProfile? = nil
    var isAuthenticated: Bool { currentUser != nil }
}
