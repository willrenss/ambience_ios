import NearbyInteraction
import Foundation

@MainActor
final class NearbyInteractionService: NSObject {
    static let shared = NearbyInteractionService()

    private var ownSession: NISession?
    private(set) var ownToken: NIDiscoveryToken?
    private var tokenContinuation: CheckedContinuation<NIDiscoveryToken?, Never>?

    // (token: peer's NIDiscoveryToken, userID) — ownSession is run with each peer's token.
    // Using ownSession (the session that generated ownToken) is required: the peer device
    // configured ITS session using OUR ownToken, so only ownSession can respond to ranging.
    private var peerTokenMap: [(token: NIDiscoveryToken, userID: UUID)] = []
    private(set) var niResults: [UUID: (distance: Float, direction: Float?, elevation: Float?)] = [:]
    private var lastNIError: String? = nil
    private(set) var isPermissionDenied = false

    // Typed callbacks — data is passed directly so callers don't need a MainActor hop
    // to re-read niResults. Called on MainActor; callers Task-hop to their own actor.
    var onNIUpdate:    (@Sendable (_ peerID: UUID, _ distance: Float, _ direction: Float?, _ elevation: Float?) -> Void)?
    var onNIRemove:    (@Sendable (_ peerID: UUID) -> Void)?
    // Fires when token arrives AFTER prepare() already timed out, so caller can re-upload presence
    var onTokenReady:  (@Sendable () -> Void)?

    private override init() { super.init() }

    // MARK: - Own session

    // Read/write the user's UWB preference; disabling immediately invalidates the session.
    var isUWBEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "uwb_enabled") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "uwb_enabled")
            if !newValue { pauseRanging() }
            // Re-enabling: ServerProximityService's next poll calls prepare() automatically.
        }
    }

    // Pause UWB without clearing callbacks — used when user toggles UWB off.
    private func pauseRanging() {
        ownSession?.invalidate()
        ownSession = nil
        ownToken   = nil
        tokenContinuation?.resume(returning: nil)
        tokenContinuation = nil
        peerTokenMap.removeAll()
        niResults.removeAll()
        lastNIError = nil
    }

    var debugStatus: String {
        let caps = NISession.deviceCapabilities
        if !caps.supportsPreciseDistanceMeasurement { return "UWB: not supported" }
        let dirCap = caps.supportsDirectionMeasurement ? "✓dir" : "✗dir"
        let tok = ownToken != nil ? "tok✓" : (ownSession != nil ? "tok⏳" : "tok✗")
        let details = niResults.isEmpty ? "—" : niResults.map { _, r in
            let dist = String(format: "%.1f", r.distance)
            let angle = r.direction.map { String(format: "%+.0f°", $0 * 180 / .pi) } ?? "?"
            return "\(dist)m \(angle)"
        }.joined(separator: " ")
        var s = "UWB:\(dirCap) \(tok) s=\(peerTokenMap.count) [\(details)]"
        if let err = lastNIError { s += " ⚠️\(err)" }
        return s
    }

    func prepare() async -> NIDiscoveryToken? {
        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement,
              isUWBEnabled
        else { return nil }
        if let token = ownToken { return token }
        return await withCheckedContinuation { cont in
            tokenContinuation = cont
            let session = NISession()
            session.delegate = self
            ownSession = session
            // 5-second timeout: Bluetooth off / permission denied causes NI to silently
            // never call didGenerateDiscoveryToken, which would hang the background Task
            // forever and prevent updatePresence() from uploading our token.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard let self, let pending = self.tokenContinuation else { return }
                self.tokenContinuation = nil
                pending.resume(returning: nil)
            }
        }
    }

    nonisolated static func encode(_ token: NIDiscoveryToken) -> String? {
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: token, requiringSecureCoding: true)
        else { return nil }
        return data.base64EncodedString()
    }

    // MARK: - Peer sessions

    func startPeerSession(peerUserID: UUID, tokenBase64: String) {
        guard let data = Data(base64Encoded: tokenBase64),
              let peerToken = try? NSKeyedUnarchiver.unarchivedObject(
                  ofClass: NIDiscoveryToken.self, from: data),
              let session = ownSession
        else { return }

        // If we're already ranging with this peer using the same token, skip.
        if peerTokenMap.contains(where: { $0.userID == peerUserID && $0.token.isEqual(peerToken) }) {
            return
        }
        // Token changed (peer restarted their session) — remove stale entry before re-adding.
        peerTokenMap.removeAll(where: { $0.userID == peerUserID })

        peerTokenMap.append((token: peerToken, userID: peerUserID))
        // Run ownSession with this peer's token. ownSession holds ownToken (which the peer
        // has already configured their session with). Calling run() with a new peer config
        // adds the peer to the running session rather than replacing existing peers (iOS 16+).
        session.run(NINearbyPeerConfiguration(peerToken: peerToken))
    }

    func stop() {
        ownSession?.invalidate()
        ownSession = nil
        ownToken = nil
        tokenContinuation?.resume(returning: nil)
        tokenContinuation = nil
        peerTokenMap.removeAll()
        niResults.removeAll()
        lastNIError = nil
        onNIUpdate   = nil
        onNIRemove   = nil
        onTokenReady = nil
    }
}

// MARK: - NISessionDelegate

extension NearbyInteractionService: NISessionDelegate {

    nonisolated func session(_ session: NISession,
                             didGenerateDiscoveryToken token: NIDiscoveryToken) {
        Task { @MainActor in
            guard session === self.ownSession else { return }
            self.ownToken = token
            if let cont = self.tokenContinuation {
                // prepare() is still waiting — resume normally
                self.tokenContinuation = nil
                cont.resume(returning: token)
            } else {
                // prepare() already timed out — re-upload presence so peer gets our token
                self.onTokenReady?()
            }
        }
    }

    nonisolated func session(_ session: NISession,
                             didUpdate nearbyObjects: [NINearbyObject]) {
        Task { @MainActor in
            guard session === self.ownSession else { return }
            for object in nearbyObjects {
                guard let peerID = self.peerTokenMap
                    .first(where: { $0.token.isEqual(object.discoveryToken) })?.userID
                else { continue }

                let dist = object.distance.map { Float($0) }
                    ?? self.niResults[peerID]?.distance ?? 1.0

                let bearing: Float? = object.direction.map { dir in
                    Float(atan2(Double(dir.x), Double(-dir.z)))
                }
                // Elevation angle from UWB — positive = peer is above phone, negative = below
                let elevation: Float? = object.direction.map { dir in
                    Float(asin(Double(max(-1.0, min(1.0, Double(dir.y))))))
                }
                self.niResults[peerID] = (dist, bearing, elevation)
                self.onNIUpdate?(peerID, dist, bearing, elevation)
            }
        }
    }

    nonisolated func session(_ session: NISession,
                             didRemove nearbyObjects: [NINearbyObject],
                             reason: NINearbyObject.RemovalReason) {
        Task { @MainActor in
            guard session === self.ownSession else { return }
            for object in nearbyObjects {
                guard let idx = self.peerTokenMap
                    .firstIndex(where: { $0.token.isEqual(object.discoveryToken) })
                else { continue }
                let peerID = self.peerTokenMap[idx].userID
                self.peerTokenMap.remove(at: idx)
                self.niResults.removeValue(forKey: peerID)
                self.onNIRemove?(peerID)
            }
        }
    }

    nonisolated func session(_ session: NISession, didInvalidateWith error: Error) {
        let errMsg = (error as NSError).localizedDescription
        let permDenied = (error as? NIError)?.code == .userDidNotAllow
        Task { @MainActor in
            self.lastNIError = errMsg
            if permDenied { self.isPermissionDenied = true }
            guard session === self.ownSession else { return }
            for (_, peerID) in self.peerTokenMap {
                self.niResults.removeValue(forKey: peerID)
                self.onNIRemove?(peerID)
            }
            self.peerTokenMap.removeAll()
        }
    }
}
