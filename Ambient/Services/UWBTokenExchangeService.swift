import MultipeerConnectivity
import Foundation

// Handles peer-to-peer NI token exchange via MultipeerConnectivity (Bluetooth/WiFi Direct).
// Same approach as UWBDemo — local exchange is faster and more reliable than going via server.
final class UWBTokenExchangeService: NSObject {
    // Called on the main thread when the peer's NI discovery token arrives.
    var onPeerTokenReceived: ((String) -> Void)?

    private let serviceType = "nowi-uwb"
    private var roomPrefix: String = ""
    private var localPeer: MCPeerID?
    private var mcSession: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var pendingToken: String?

    func start(roomID: UUID) {
        stop()
        roomPrefix = String(roomID.uuidString.prefix(8)).lowercased()

        let peer = MCPeerID(displayName: UIDevice.current.name)
        localPeer = peer

        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        mcSession = session

        let adv = MCNearbyServiceAdvertiser(
            peer: peer,
            discoveryInfo: ["r": roomPrefix],
            serviceType: serviceType
        )
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv

        let brw = MCNearbyServiceBrowser(peer: peer, serviceType: serviceType)
        brw.delegate = self
        brw.startBrowsingForPeers()
        browser = brw

        log("🔍 MC start — device='\(peer.displayName)' room=\(roomPrefix)")
    }

    // Call after prepare() returns a token. Sends to any already-connected MC peers,
    // or buffers it to be sent when the connection establishes.
    func sendToken(_ base64: String) {
        pendingToken = base64
        guard let session = mcSession, !session.connectedPeers.isEmpty else {
            log("📦 Token buffered (belum ada MC peer yang connected)")
            return
        }
        deliver(base64, to: session.connectedPeers)
    }

    func stop() {
        if localPeer != nil { log("🛑 MC stop") }
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        mcSession?.disconnect()
        advertiser = nil
        browser = nil
        mcSession = nil
        localPeer = nil
        pendingToken = nil
        onPeerTokenReceived = nil
        roomPrefix = ""
    }

    private func deliver(_ base64: String, to peers: [MCPeerID]) {
        guard let data = base64.data(using: .utf8),
              let session = mcSession,
              !peers.isEmpty
        else { return }
        do {
            try session.send(data, toPeers: peers, with: .reliable)
            let names = peers.map(\.displayName).joined(separator: ", ")
            log("📤 Token dikirim via MC ke '\(names)' ✅")
        } catch {
            log("❌ Gagal kirim token via MC: \(error.localizedDescription)")
        }
    }

    private func log(_ message: String) {
        DispatchQueue.main.async {
            UWBLogger.shared.append("[MC] \(message)")
        }
    }
}

// MARK: - MCSessionDelegate

extension UWBTokenExchangeService: MCSessionDelegate {
    func session(_ session: MCSession, peer: MCPeerID, didChange state: MCSessionState) {
        let stateStr: String
        switch state {
        case .notConnected: stateStr = "Disconnected"
        case .connecting:   stateStr = "Connecting..."
        case .connected:    stateStr = "Connected ✅"
        @unknown default:   stateStr = "Unknown"
        }
        log("Peer '\(peer.displayName)': \(stateStr)")

        if state == .connected, let token = pendingToken {
            deliver(token, to: [peer])
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer: MCPeerID) {
        guard let token = String(data: data, encoding: .utf8) else {
            log("❌ Data dari '\(fromPeer.displayName)' bukan UTF-8 string")
            return
        }
        log("📥 Token diterima via MC dari '\(fromPeer.displayName)' ✅")
        let cb = onPeerTokenReceived
        DispatchQueue.main.async { cb?(token) }
    }

    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension UWBTokenExchangeService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peer: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let alreadyConnected = mcSession?.connectedPeers.contains(peer) ?? false
        guard !alreadyConnected else {
            log("ℹ️ Invitation dari '\(peer.displayName)' — sudah connected, tolak duplikat")
            invitationHandler(false, nil)
            return
        }
        log("📨 Invitation dari '\(peer.displayName)', menerima...")
        invitationHandler(true, mcSession)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didNotStartAdvertisingPeer error: Error) {
        log("⚠️ MC Advertiser gagal (non-fatal, WebSocket tetap jalan): \(error.localizedDescription)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension UWBTokenExchangeService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peer: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        let peerRoom = info?["r"] ?? "nil"
        let match = peerRoom == roomPrefix && !roomPrefix.isEmpty
        guard match, let session = mcSession else {
            log("🔎 Ketemu '\(peer.displayName)' room=\(peerRoom) → beda room, skip")
            return
        }
        let alreadyConnected = session.connectedPeers.contains(peer)
        guard !alreadyConnected else {
            log("ℹ️ Ketemu '\(peer.displayName)' room=\(peerRoom) → sudah connected, skip duplikat invite")
            return
        }
        log("🔎 Ketemu '\(peer.displayName)' room=\(peerRoom) → MATCH, invite")
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        log("👋 Peer '\(peerID.displayName)' hilang")
    }

    func browser(_ browser: MCNearbyServiceBrowser,
                 didNotStartBrowsingForPeers error: Error) {
        log("⚠️ MC Browser gagal (non-fatal, WebSocket tetap jalan): \(error.localizedDescription)")
    }
}
