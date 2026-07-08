import Observation
import Foundation

let kActiveEventIDKey             = "nowi_active_event_id"
let kFocusTargetIDKey             = "nowi_focus_target_user_id"
let kHasSeenPermissionsPrimingKey = "nowi_has_seen_permissions_priming"
let kHasSeenWalkthroughKey        = "nowi_has_seen_walkthrough"

@Observable
final class AppState: @unchecked Sendable {
    // @unchecked Sendable: mutated on MainActor only; @Observable doesn't synthesize Sendable.
    var currentUser: UserProfile? = nil
    var isAuthenticated: Bool { currentUser != nil }

    // Programmatic tab switching — set from EventDetailView (check-in) and HomeView (check-out).
    var selectedTab: AppTab = .maps

    // Shown once, right after account creation — gates the GPS/Bluetooth/
    // Notifications priming screens so a returning (restored-session) user
    // never sees them again.
    var hasSeenPermissionsPriming: Bool = UserDefaults.standard.bool(forKey: kHasSeenPermissionsPrimingKey) {
        didSet {
            UserDefaults.standard.set(hasSeenPermissionsPriming, forKey: kHasSeenPermissionsPrimingKey)
        }
    }

    var hasSeenWalkthrough: Bool = UserDefaults.standard.bool(forKey: kHasSeenWalkthroughKey) {
        didSet {
            UserDefaults.standard.set(hasSeenWalkthrough, forKey: kHasSeenWalkthroughKey)
        }
    }

    // Set once the user joins an event and radar is eligible.
    var activeEventID: UUID? {
        didSet {
            UserDefaults.standard.set(activeEventID?.uuidString, forKey: kActiveEventIDKey)
        }
    }
    var activeEvent: EventDTO? = nil

    // Set by StatusIntentView — HomeView observes and auto-connects to radar.
    var shouldAutoConnectRadar: Bool = false

    // The radar blip currently focused (used as the Back Tap ping target).
    var focusTargetUserID: UUID? {
        didSet {
            UserDefaults.standard.set(focusTargetUserID?.uuidString, forKey: kFocusTargetIDKey)
        }
    }
}
