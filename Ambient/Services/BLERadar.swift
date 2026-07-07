import CoreBluetooth
import Foundation

// Tier-2 radar transport. Advertises our own radarToken and scans for peers,
// reporting smoothed RSSI keyed by the peer's advertised radarToken so a listener
// can correlate a hit back to a specific EventRadarUserDTO.
//
// @unchecked Sendable: all mutable state is confined to `queue`.
final class BLERadar: NSObject, @unchecked Sendable {

    // Service UUID identifying Nowi radar advertisements.
    private static let serviceUUID = CBUUID(string: "AC2F5D8E-3B7E-4C5D-9AB3-4F1C2D8E3A90")

    // Called with (radarToken, smoothedRSSI) on every correlated scan hit.
    nonisolated(unsafe) var onPeerRSSI: (@Sendable (_ radarToken: String, _ rssi: Int) -> Void)?
    // Called when a previously-seen token has gone silent past the stale window.
    nonisolated(unsafe) var onPeerLost: (@Sendable (_ radarToken: String) -> Void)?

    private var peripheral: CBPeripheralManager?
    private var central: CBCentralManager?
    private let queue = DispatchQueue(label: "com.nowi.ble.radar", qos: .userInitiated)

    private var ownToken: String = ""
    private var rssiWindows: [String: [Int]] = [:]   // rolling RSSI samples per token
    private var lastSeen: [String: Date] = [:]
    private var sweepTimer: DispatchSourceTimer?

    private let windowSize = 6
    private let staleAfter: TimeInterval = 6

    // Explicit nonisolated init so actors can create BLERadar without @MainActor hop.
    nonisolated override init() { super.init() }

    nonisolated func start(ownRadarToken: String) {
        queue.async { [self] in
            ownToken = ownRadarToken
            rssiWindows.removeAll()
            lastSeen.removeAll()
            if peripheral == nil {
                peripheral = CBPeripheralManager(delegate: self, queue: queue)
            } else {
                restartAdvertising()
            }
            if central == nil {
                central = CBCentralManager(delegate: self, queue: queue)
            } else if central?.state == .poweredOn {
                startScan()
            }
            startSweep()
        }
    }

    nonisolated func stop() {
        queue.async { [self] in
            sweepTimer?.cancel()
            sweepTimer = nil
            peripheral?.stopAdvertising()
            central?.stopScan()
            peripheral = nil
            central = nil
            rssiWindows.removeAll()
            lastSeen.removeAll()
        }
    }

    // MARK: - Private (queue-isolated)

    private nonisolated func startScan() {
        central?.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    private nonisolated func restartAdvertising() {
        guard peripheral?.state == .poweredOn, !ownToken.isEmpty else { return }
        peripheral?.stopAdvertising()
        // iOS drops CBAdvertisementDataLocalNameKey from the actual advertisement the
        // moment the app is backgrounded (screen-locked phones at an event are the norm),
        // so local name alone can't reliably carry the radarToken. Service UUIDs, unlike
        // local name, do survive background advertising — so we also encode the token as
        // a second, per-user service UUID and read it back on the scanning side.
        var advertisement: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
            CBAdvertisementDataLocalNameKey: ownToken,
        ]
        if let tokenUUID = Self.tokenUUID(forHexToken: ownToken) {
            advertisement[CBAdvertisementDataServiceUUIDsKey] = [Self.serviceUUID, tokenUUID]
        }
        peripheral?.startAdvertising(advertisement)
    }

    private nonisolated func startSweep() {
        sweepTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in self?.expireStale() }
        timer.resume()
        sweepTimer = timer
    }

    private nonisolated func expireStale() {
        let now = Date()
        for (token, seen) in lastSeen where now.timeIntervalSince(seen) > staleAfter {
            lastSeen.removeValue(forKey: token)
            rssiWindows.removeValue(forKey: token)
            onPeerLost?(token)
        }
    }

    private nonisolated func record(token: String, rssi: Int) {
        guard token != ownToken, rssi != 127 else { return }
        var window = rssiWindows[token] ?? []
        window.append(rssi)
        if window.count > windowSize { window.removeFirst(window.count - windowSize) }
        rssiWindows[token] = window
        lastSeen[token] = Date()
        let smoothed = window.reduce(0, +) / window.count
        onPeerRSSI?(token, smoothed)
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLERadar: CBPeripheralManagerDelegate {
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else { return }
        restartAdvertising()
    }
}

// MARK: - CBCentralManagerDelegate

extension BLERadar: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        startScan()
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        // Foreground fast path: local name is present and cheap to read.
        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String, !name.isEmpty {
            record(token: name, rssi: RSSI.intValue)
            return
        }
        // Background fallback: recover the token from the per-user service UUID,
        // since local name is stripped from background advertisements by iOS.
        if let uuids = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID],
           let tokenUUID = uuids.first(where: { $0 != Self.serviceUUID }),
           let token = BLERadar.hexToken(from: tokenUUID) {
            record(token: token, rssi: RSSI.intValue)
        }
    }
}

// RSSI → approximate meters via log-distance path loss (spec Tier 2 formula).
enum RSSIDistance {
    // TxPower: RSSI at 1m; N: path-loss exponent (higher in crowded venues).
    nonisolated static func meters(rssi: Int, txPower: Int = -59, n: Double = 2.5) -> Float {
        Float(pow(10.0, (Double(txPower) - Double(rssi)) / (10.0 * n)))
    }
}

// MARK: - Token <-> UUID encoding
//
// The server's radarToken is 16 hex chars (8 bytes). We fold it into a 128-bit
// UUID behind a fixed namespace prefix so it round-trips through CBUUID, which
// (unlike local name) iOS keeps present in background advertisements.
private extension BLERadar {
    static let uuidNamespaceHex = "6e4f1a2b9c3d5e70"  // fixed 8-byte prefix, arbitrary but stable

    static func tokenUUID(forHexToken token: String) -> CBUUID? {
        guard token.count == 16, token.allSatisfy(\.isHexDigit) else { return nil }
        let hex = uuidNamespaceHex + token
        return CBUUID(string: Self.formatAsUUIDString(hex))
    }

    static func hexToken(from uuid: CBUUID) -> String? {
        let hex = uuid.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        guard hex.count == 32, hex.hasPrefix(uuidNamespaceHex) else { return nil }
        return String(hex.suffix(16))
    }

    static func formatAsUUIDString(_ hex32: String) -> String {
        func group(_ range: Range<Int>) -> String {
            let start = hex32.index(hex32.startIndex, offsetBy: range.lowerBound)
            let end = hex32.index(hex32.startIndex, offsetBy: range.upperBound)
            return String(hex32[start..<end])
        }
        return [group(0..<8), group(8..<12), group(12..<16), group(16..<20), group(20..<32)]
            .joined(separator: "-")
    }
}
