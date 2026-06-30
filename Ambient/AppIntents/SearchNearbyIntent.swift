import AppIntents
import Foundation

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
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
        }
        return .result()
    }
}

// MARK: - Shortcuts registration

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
            systemImageName: "dot.radiowaves.left.and.right"
        )
    }
}

extension Notification.Name {
    static let searchNearbyTriggered = Notification.Name("com.ambientsocial.searchNearbyTriggered")
}
