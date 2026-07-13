import UIKit
import UserNotifications

extension Notification.Name {
    static let pushNotificationOpenRoom = Notification.Name("com.nowi.pushNotificationOpenRoom")
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    // Set once by AmbientApp — delegates sit outside the SwiftUI view tree, so
    // this is how notification handling reaches the shared app state.
    static var appState: AppState?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Re-register on every launch (not just after the priming screen) since
        // tokens can rotate; this only re-triggers the OS prompt if permission
        // was never decided, otherwise it's silent.
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                application.registerForRemoteNotifications()
            default:
                break
            }
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await AuthService.shared.updateDeviceToken(token) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Non-fatal — push just isn't reachable this session (Simulator, no
        // Push Notifications entitlement yet, etc.). Nothing to recover from here.
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Suppress the banner only for a "message" push about the room already on screen.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        let roomID = (userInfo["roomID"] as? String).flatMap(UUID.init)
        let isOpenRoomMessage = await MainActor.run {
            userInfo["type"] as? String == "message" && roomID != nil && roomID == AppDelegate.appState?.openRoomID
        }
        return isOpenRoomMessage ? [] : [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run { Self.handleTap(userInfo: userInfo) }
    }

    @MainActor
    private static func handleTap(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }
        let roomID = (userInfo["roomID"] as? String).flatMap(UUID.init)

        switch type {
        case "message":
            appState?.selectedTab = .bookmarks
            if let roomID {
                NotificationCenter.default.post(name: .pushNotificationOpenRoom, object: roomID)
            }
        case "match":
            // Matches list, not straight into the room — mirrors the in-app
            // mutual-match flow, which never auto-navigates either.
            appState?.selectedTab = .bookmarks
        case "ping":
            appState?.selectedTab = .maps
        default:
            break
        }
    }
}
