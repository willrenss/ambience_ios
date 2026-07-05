import Observation
import Foundation

<<<<<<< HEAD
@Observable
final class AppState: @unchecked Sendable {
    // @unchecked Sendable: AppState is only mutated on MainActor in practice;
    // @Observable synthesis does not currently add Sendable conformance automatically.
    var currentUser: UserProfile? = nil
    var isAuthenticated: Bool { currentUser != nil }
=======
// Session/UserDefaults keys shared with AppIntents (which run outside the app process
// and can only read persisted state, not @Observable memory).
let kActiveEventIDKey  = "nowi_active_event_id"
let kFocusTargetIDKey  = "nowi_focus_target_user_id"
let kHasSeenPermissionsPrimingKey = "nowi_has_seen_permissions_priming"

@Observable
final class AppState: @unchecked Sendable {
    // @unchecked Sendable: mutated on MainActor only; @Observable doesn't synthesize Sendable.
    var currentUser: UserProfile? = nil
    var isAuthenticated: Bool { currentUser != nil }

    // Shown once, right after account creation — gates the GPS/Bluetooth/
    // Notifications priming screens so a returning (restored-session) user
    // never sees them again.
    var hasSeenPermissionsPriming: Bool = UserDefaults.standard.bool(forKey: kHasSeenPermissionsPrimingKey) {
        didSet {
            UserDefaults.standard.set(hasSeenPermissionsPriming, forKey: kHasSeenPermissionsPrimingKey)
        }
    }

    // Set once the user joins an event and radar is eligible.
    var activeEventID: UUID? {
        didSet {
            UserDefaults.standard.set(activeEventID?.uuidString, forKey: kActiveEventIDKey)
        }
    }
    var activeEvent: EventDTO? = nil

    // The radar blip currently focused (used as the Back Tap ping target).
    var focusTargetUserID: UUID? {
        didSet {
            UserDefaults.standard.set(focusTargetUserID?.uuidString, forKey: kFocusTargetIDKey)
        }
    }
>>>>>>> c5f4022 (Iniatial Commit)
}
