import AppIntents
import Foundation

<<<<<<< HEAD
// MARK: - Wave Intent (runs silently, no app open)

struct WaveIntent: AppIntent {
    static var title: LocalizedStringResource = "Wave to Nearby People"
    static var description = IntentDescription("Send a haptic wave signal to nearby Ambient Social users")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        guard let token = KeychainHelper.shared.load(forKey: "ambsocial_token") else {
            return .result()
        }
        let serverURL = await MainActor.run {
            UserDefaults.standard.string(forKey: serverURLKey) ?? serverFallbackURL
        }
        guard let url = URL(string: "\(serverURL)/presence/wave") else {
            return .result()
        }
=======
// MARK: - Ping Intent (Back Tap target)
//
// Back Tap has no direct iOS API — it can only trigger an App Intent that the user
// manually assigns via Settings > Accessibility > Touch > Back Tap. This intent runs
// silently (no app open) and pings whichever radar blip is currently focused, using
// the active event + focus target persisted in UserDefaults by the running app.
struct PingIntent: AppIntent {
    static var title: LocalizedStringResource = "Ping Nearby Person"
    static var description = IntentDescription("Ping the person currently focused on your Nowi radar")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        guard let token = KeychainHelper.shared.load(forKey: kAuthTokenKey) else {
            return .result()
        }
        let (serverURL, eventIDString, targetIDString) = await MainActor.run {
            (UserDefaults.standard.string(forKey: serverURLKey) ?? serverFallbackURL,
             UserDefaults.standard.string(forKey: kActiveEventIDKey),
             UserDefaults.standard.string(forKey: kFocusTargetIDKey))
        }
        guard let eventIDString, let targetIDString,
              let targetID = UUID(uuidString: targetIDString),
              let url = URL(string: "\(serverURL)/events/\(eventIDString)/ping")
        else { return .result() }

        // Tap-confirmation haptic fires immediately on Back Tap detection.
        await MainActor.run { HapticManager.shared.play(.sendPing) }

>>>>>>> c5f4022 (Iniatial Commit)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
<<<<<<< HEAD
        request.httpBody    = Data("{}".utf8)
        request.timeoutInterval = 5
        _ = try? await URLSession.shared.data(for: request)
        return .result()
    }
}

// MARK: - Search Nearby Intent (opens app)

struct SearchNearbyIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Nearby"
    static var description = IntentDescription("Open Ambient Social and start scanning for nearby people")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .searchNearbyTriggered, object: nil)
=======
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["toUserID": targetID.uuidString])
        request.timeoutInterval = 5

        if let (data, _) = try? await URLSession.shared.data(for: request),
           let resp = try? JSONDecoder().decode(PingResponse.self, from: data),
           resp.mutual {
            await MainActor.run {
                HapticManager.shared.play(.mutualMatch)
                if let roomID = resp.roomID {
                    NotificationCenter.default.post(name: .mutualMatchCreated, object: roomID)
                }
            }
>>>>>>> c5f4022 (Iniatial Commit)
        }
        return .result()
    }
}

// MARK: - Shortcuts registration

<<<<<<< HEAD
struct AmbientShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WaveIntent(),
            phrases: [
                "Wave nearby in \(.applicationName)",
                "Send wave in \(.applicationName)"
            ],
            shortTitle: "Wave to Nearby",
            systemImageName: "hand.wave.fill"
        )
        AppShortcut(
            intent: SearchNearbyIntent(),
            phrases: [
                "Search nearby in \(.applicationName)",
                "Open \(.applicationName) radar"
            ],
            shortTitle: "Search Nearby",
=======
struct NowiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PingIntent(),
            phrases: [
                "Ping nearby in \(.applicationName)",
                "Send ping in \(.applicationName)"
            ],
            shortTitle: "Ping Nearby",
>>>>>>> c5f4022 (Iniatial Commit)
            systemImageName: "dot.radiowaves.left.and.right"
        )
    }
}

extension Notification.Name {
<<<<<<< HEAD
    static let searchNearbyTriggered = Notification.Name("com.ambientsocial.searchNearbyTriggered")
=======
    static let mutualMatchCreated = Notification.Name("com.nowi.mutualMatchCreated")
>>>>>>> c5f4022 (Iniatial Commit)
}
