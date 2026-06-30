import Foundation
import CoreBluetooth
import UIKit

protocol ProximityServiceProtocol: Actor {
    var nearbyUsersStream: AsyncStream<[NearbyUser]> { get }
    func startScanning() async throws
    func stopScanning() async
}

// Valid 128-bit UUID that identifies the Ambient Social app in BLE advertisements
private let ambientServiceUUID = CBUUID(string: "A4F5E6B7-9D8C-4B2A-B1E0-3F5C6D7E8F90")

actor ProximityService: NSObject, ProximityServiceProtocol {
    static let shared = ProximityService()

    private(set) var nearbyUsersStream: AsyncStream<[NearbyUser]>
    private var streamContinuation: AsyncStream<[NearbyUser]>.Continuation?

    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var centralDelegate: CentralDelegate?
    private var peripheralDelegate: PeripheralDelegate?

    private var discoveredPeers: [UUID: NearbyUser] = [:]
    private var isScanning = false

    override init() {
        var cont: AsyncStream<[NearbyUser]>.Continuation?
        nearbyUsersStream = AsyncStream { cont = $0 }
        streamContinuation = cont
        super.init()
    }

    func startScanning() async throws {
        guard !isScanning else { return }
        isScanning = true

        let cDelegate = CentralDelegate(owner: self)
        let pDelegate = PeripheralDelegate(owner: self)
        centralDelegate = cDelegate
        peripheralDelegate = pDelegate

        centralManager = CBCentralManager(delegate: cDelegate, queue: .global(qos: .userInitiated))
        peripheralManager = CBPeripheralManager(delegate: pDelegate, queue: .global(qos: .userInitiated))
    }

    func stopScanning() async {
        isScanning = false
        centralManager?.stopScan()
        centralManager = nil
        peripheralManager?.stopAdvertising()
        peripheralManager = nil
        centralDelegate = nil
        peripheralDelegate = nil
        discoveredPeers.removeAll()
        streamContinuation?.yield([])
    }

    func didDiscover(peripheralID: UUID, name: String?, rssi: Int) async {
        let displayName = name ?? "Unknown"
        let distance = Self.rssiToMeters(rssi)
        let direction = Self.stableAngle(for: peripheralID)

        discoveredPeers[peripheralID] = NearbyUser(
            id: peripheralID,
            displayName: displayName,
            distance: distance,
            direction: direction,
            isOpen: true
        )
        streamContinuation?.yield(Array(discoveredPeers.values))
    }

    func didLose(peripheralID: UUID) async {
        discoveredPeers.removeValue(forKey: peripheralID)
        streamContinuation?.yield(Array(discoveredPeers.values))
    }

    func startAdvertising() async {
        let displayName = UserDefaults.standard.string(forKey: "ambsocial_display_name")
            ?? UIDevice.current.name
        peripheralManager?.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [ambientServiceUUID],
            CBAdvertisementDataLocalNameKey: displayName
        ])
    }

    // RSSI → approximate meters (free-space path loss)
    private static func rssiToMeters(_ rssi: Int) -> Float {
        guard rssi != 127 else { return 5.0 }
        let txPower: Float = -59  // iPhone RSSI at 1 meter
        return pow(10.0, (txPower - Float(rssi)) / 20.0)
    }

    // Spread users around the radar deterministically by UUID
    private static func stableAngle(for uuid: UUID) -> Float {
        let firstByte = uuid.uuid.0
        return Float(firstByte) / Float(UInt8.max) * 2 * Float.pi
    }
}

// MARK: - Central (scanner)

private final class CentralDelegate: NSObject, CBCentralManagerDelegate, @unchecked Sendable {
    private weak var owner: ProximityService?
    init(owner: ProximityService) { self.owner = owner }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        central.scanForPeripherals(
            withServices: [ambientServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard let owner else { return }
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
                   ?? peripheral.name
        Task { await owner.didDiscover(peripheralID: peripheral.identifier, name: name, rssi: RSSI.intValue) }
    }
}

// MARK: - Peripheral (advertiser)

private final class PeripheralDelegate: NSObject, CBPeripheralManagerDelegate, @unchecked Sendable {
    private weak var owner: ProximityService?
    init(owner: ProximityService) { self.owner = owner }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else { return }
        Task { await owner?.startAdvertising() }
    }
}
