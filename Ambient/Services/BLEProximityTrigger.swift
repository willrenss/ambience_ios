import CoreBluetooth
import Foundation

private let kAppServiceUUID = CBUUID(string: "AC2F5D8E-3B7E-4C5D-9AB3-4F1C2D8E3A90")

// Advertises the app's BLE presence and detects other nearby instances.
// On discovery, fires `onNearbyAppDetected` so the caller can trigger an
// immediate server fetch — reducing UWB handshake latency from ~2s to ~300ms.
//
// @unchecked Sendable: all mutable state is accessed exclusively on `queue`.
final class BLEProximityTrigger: NSObject, @unchecked Sendable {
    static let shared = BLEProximityTrigger()
    nonisolated(unsafe) var onNearbyAppDetected: (@Sendable () -> Void)?

    private var peripheral: CBPeripheralManager?
    private var central: CBCentralManager?
    private let queue = DispatchQueue(label: "social.ambient.ble", qos: .utility)
    private var lastTrigger: Date = .distantPast

    private override init() { super.init() }

    func start() {
        queue.async { [self] in
            peripheral = CBPeripheralManager(delegate: self, queue: queue)
            central    = CBCentralManager(delegate: self, queue: queue)
        }
    }

    func stop() {
        queue.async { [self] in
            peripheral?.stopAdvertising()
            central?.stopScan()
            peripheral = nil
            central    = nil
        }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLEProximityTrigger: CBPeripheralManagerDelegate {
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else { return }
        peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [kAppServiceUUID]])
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEProximityTrigger: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        central.scanForPeripherals(
            withServices: [kAppServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let now = Date()
        guard now.timeIntervalSince(lastTrigger) > 2 else { return }
        lastTrigger = now
        onNearbyAppDetected?()
    }
}
