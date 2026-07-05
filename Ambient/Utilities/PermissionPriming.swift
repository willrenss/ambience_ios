import CoreBluetooth
import UserNotifications

// Merely instantiating a CBCentralManager triggers the system Bluetooth
// permission prompt on first use — there's no direct "request" API like
// CLLocationManager has. Kept as a singleton so the manager isn't deallocated
// mid-prompt, and reused later by BLERadar's own managers once radar starts.
@MainActor
final class BluetoothPermissionPrimer: NSObject, CBCentralManagerDelegate {
    static let shared = BluetoothPermissionPrimer()
    private var manager: CBCentralManager?

    func request() {
        guard manager == nil else { return }
        manager = CBCentralManager(delegate: self, queue: .main)
    }

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {}
}

enum NotificationPermissionPrimer {
    static func request() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
}
