import Observation
import Foundation

let kActiveEventIDKey             = "nowi_active_event_id"
let kFocusTargetIDKey             = "nowi_focus_target_user_id"
let kHasSeenPermissionsPrimingKey = "nowi_has_seen_permissions_priming"
let kHasSeenWalkthroughKey        = "nowi_has_seen_walkthrough"
let kLastSeenByRoomKey            = "nowi_last_seen_by_room"

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

    // Whether the radar (HomeView) full-screen cover is up. Lives here rather than
    // as EventMapView local @State because switching to the chat tab and back
    // recreates EventMapView from scratch — a local flag would reset to false and
    // strand the user on the map instead of back in radar.
    var isRadarPresented: Bool = false

    // Whether EventMapView's in-place search overlay is up. Lives here (not local
    // @State) for the same reason as isRadarPresented — MainTabView needs to see it
    // to hide the floating tab bar while search is showing.
    var isSearchPresented: Bool = false

    // Set by StatusIntentView — HomeView observes and auto-connects to radar.
    var shouldAutoConnectRadar: Bool = false

    // The radar blip currently focused (used as the Back Tap ping target).
    var focusTargetUserID: UUID? {
        didSet {
            UserDefaults.standard.set(focusTargetUserID?.uuidString, forKey: kFocusTargetIDKey)
        }
    }

    // Durable "unread" watermark: the timestamp of the newest message the user has
    // actually seen in each room. "Unread" is derived from this (see isUnread) rather
    // than tracked as a mutable flag, so it can't be corrupted by view teardown or a
    // dropped stream event — any fetch recomputes the correct answer from this + the
    // room's server updatedAt. Persisted so it survives relaunch.
    var lastSeenByRoom: [UUID: Date] = AppState.loadLastSeen() {
        didSet { AppState.saveLastSeen(lastSeenByRoom) }
    }

    // Derived, non-persisted set of rooms that currently have an unread peer message.
    // Rebuilt from a fetched room list by whoever polls (radar poll while HomeView is
    // up; MatchesViewModel while the chat list is up) via recomputeUnread. Drives the
    // chat-entry badge; the per-row highlight uses isUnread(_:) directly instead.
    var unreadRoomIDs: Set<UUID> = []
    var hasUnseenMatches: Bool { !unreadRoomIDs.isEmpty }

    /// A room is unread iff its last message was sent by the peer (not us) and is
    /// newer than the watermark of what we've seen. Pure function of durable state —
    /// no per-session baseline to reset.
    func isUnread(_ room: RoomDTO, ownUserID: UUID?) -> Bool {
        guard let sender = room.lastMessageSenderID, sender != ownUserID else { return false }
        let last = room.updatedAt ?? .distantPast
        return last > (lastSeenByRoom[room.id] ?? .distantPast)
    }

    /// Recompute the whole unread set from a fresh, authoritative room list.
    func recomputeUnread(from rooms: [RoomDTO], ownUserID: UUID?) {
        unreadRoomIDs = Set(rooms.filter { isUnread($0, ownUserID: ownUserID) }.map(\.id))
    }

    /// Advance the seen-watermark for a room (monotonic — only moves forward) and
    /// clear its unread flag immediately. Called when the user opens/reads the room.
    func markRoomSeen(roomID: UUID, upTo date: Date) {
        let existing = lastSeenByRoom[roomID] ?? .distantPast
        if date > existing { lastSeenByRoom[roomID] = date }
        unreadRoomIDs.remove(roomID)
    }

    // MARK: - lastSeenByRoom persistence ([UUID: Date] ⇄ [String: Double] in UserDefaults)

    private static func loadLastSeen() -> [UUID: Date] {
        guard let raw = UserDefaults.standard.dictionary(forKey: kLastSeenByRoomKey) as? [String: Double] else {
            return [:]
        }
        var out: [UUID: Date] = [:]
        for (key, seconds) in raw {
            if let id = UUID(uuidString: key) { out[id] = Date(timeIntervalSince1970: seconds) }
        }
        return out
    }

    private static func saveLastSeen(_ map: [UUID: Date]) {
        let raw = Dictionary(uniqueKeysWithValues: map.map { ($0.key.uuidString, $0.value.timeIntervalSince1970) })
        UserDefaults.standard.set(raw, forKey: kLastSeenByRoomKey)
    }
}
