import Foundation

let serverURLKey      = "ambsocial_server_url"
let serverFallbackURL = "http://31.97.50.31:8080"

enum ServerConfig {
    // Aliases so existing callsites don't need to change.
    static let urlKey: String   = serverURLKey
    static let fallback: String = serverFallbackURL

    // UserDefaults access is @MainActor in iOS 18 SDK; mark callers accordingly.
    @MainActor static var currentURL: String {
        UserDefaults.standard.string(forKey: urlKey) ?? fallback
    }

    @MainActor static func setURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: urlKey)
        // Keep APIClient in sync so actor-isolated code always gets the fresh URL
        Task { await APIClient.shared.updateBaseURL(url) }
    }
}
