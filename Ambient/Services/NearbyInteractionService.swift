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
    // Throttle ranging logs — only log when distance changes by ≥ 20 cm
    private var lastLoggedDistance: [UUID: Float] = [:]

    var onNIUpdate:   (@Sendable (_ peerID: UUID, _ distance: Float, _ direction: Float?, _ elevation: Float?) -> Void)?
    var onNIRemove:   (@Sendable (_ peerID: UUID) -> Void)?
    var onTokenReady: (@Sendable () -> Void)?

    private override init() { super.init() }

    // MARK: - Own session

    var isSessionAlive: Bool { ownSession != nil }

    var isUWBEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "uwb_enabled") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "uwb_enabled")
            if !newValue { pauseRanging() }
        }
    }

    private func pauseRanging() {
        log("⏸ UWB dimatikan — invalidate session")
        ownSession?.invalidate()
        ownSession = nil
        ownToken   = nil
        tokenContinuation?.resume(returning: nil)
        tokenContinuation = nil
        peerTokenMap.removeAll()
        niResults.removeAll()
        lastNIError = nil
        lastLoggedDistance.removeAll()
    }

    var debugStatus: String {
        let tok = ownToken != nil ? "tok✓" : (ownSession != nil ? "tok⏳" : "tok✗")
        let details = niResults.isEmpty ? "—" : niResults.map { _, r in
            String(format: "%.0fcm", r.distance * 100)
        }.joined(separator: " ")
        var s = "UWB: \(tok) peers=\(peerTokenMap.count) [\(details)]"
        if let err = lastNIError { s += " ⚠️\(err)" }
        return s
    }

    // Creates NISession immediately without waiting — triggers the iOS permission dialog
    // the first time it runs. Called from MainTabView so the dialog appears at login,
    // not buried in the chat room flow.
    func requestPermissionIfNeeded() {
        guard isUWBEnabled, !isPermissionDenied else { return }
        // Always log device capabilities so we know what the hardware supports.
        let caps = NISession.deviceCapabilities
        log("📱 deviceCapabilities: direction=\(caps.supportsDirectionMeasurement) camera=\(caps.supportsCameraAssistance)")
        guard ownSession == nil else {
            log("ℹ️ requestPermissionIfNeeded: session sudah ada (token=\(ownToken != nil ? "✓" : "pending")), skip")
            return
        }
        log("📍 Membuat NISession untuk memicu permission dialog...")
        let session = NISession()
        session.delegate = self
        ownSession = session
        // Immediately check if token is already available (property may be set before delegate fires).
        if let token = session.discoveryToken {
            log("✅ discoveryToken available immediately via property")
            ownToken = token
            onTokenReady?()
        }
    }

    func prepare() async -> NIDiscoveryToken? {
        guard isUWBEnabled else {
            log("⚠️ prepare(): UWB disabled")
            return nil
        }
        if let token = ownToken {
            log("✅ prepare(): token sudah ready, return langsung")
            return token
        }

        // Attempt 1: use existing session or create new one
        if ownSession == nil {
            guard !isPermissionDenied else { return nil }
            log("🔧 prepare() [attempt 1]: membuat NISession baru...")
            let s = NISession(); s.delegate = self; ownSession = s
        } else {
            log("🔧 prepare() [attempt 1]: reuse session, menunggu token...")
        }

        let first = await waitForToken(seconds: 10, label: "attempt 1")
        if let t = first { return t }
        guard isUWBEnabled, !isPermissionDenied else { return nil }

        // Attempt 2: force-recreate session — handles silent-fail case (no token, no
        // invalidation) that can happen due to device/region quirks.
        if ownSession != nil {
            log("🔄 prepare() [attempt 2]: session hidup tapi tidak ada token — buat ulang NISession...")
            ownSession?.invalidate()   // triggers didInvalidateWith for old session (ignored via guard)
            ownSession = nil
        } else {
            log("🔄 prepare() [attempt 2]: session sudah mati — buat ulang NISession...")
        }
        guard !isPermissionDenied else { return nil }

        log("🔧 prepare() [attempt 2]: membuat NISession baru...")
        let s2 = NISession(); s2.delegate = self; ownSession = s2

        let second = await waitForToken(seconds: 8, label: "attempt 2")
        if second == nil {
            log("❌ prepare(): gagal setelah 2 attempt (18s total). Cek Settings > Privacy > Nearby Interactions.")
        }
        return second
    }

    // Called by the retry loop when prepare() timed out — discards stale session and
    // creates a fresh NISession so iOS gets another chance to generate the token.
    func retryTokenGeneration() {
        guard isUWBEnabled, !isPermissionDenied, ownToken == nil else { return }
        log("🔄 retryTokenGeneration: buat ulang NISession baru...")
        ownSession?.invalidate()
        ownSession = nil
        ownToken = nil
        let s = NISession(); s.delegate = self; ownSession = s
    }

    // Waits for didGenerateDiscoveryToken up to `seconds`. Returns nil on timeout.
    // Also polls the session's discoveryToken property every 0.3s (UWBDemo pattern) in case
    // the delegate method is delayed or doesn't fire.
    private func waitForToken(seconds: Double, label: String) async -> NIDiscoveryToken? {
        if let token = ownToken { return token }
        if let token = ownSession?.discoveryToken {
            log("✅ token via property check (antes delegate)")
            ownToken = token; return token
        }
        return await withCheckedContinuation { cont in
            tokenContinuation = cont
            Task { @MainActor [weak self] in
                var elapsed = 0.0
                while elapsed < seconds {
                    try? await Task.sleep(for: .seconds(0.3))
                    elapsed += 0.3
                    guard let self else { return }
                    // Check property — in case delegate fires late or not at all
                    if self.ownToken != nil {
                        // Delegate already resumed the continuation — just exit the poll
                        return
                    }
                    if let token = self.ownSession?.discoveryToken, self.tokenContinuation != nil {
                        self.log("✅ token via property poll (\(String(format: "%.1f", elapsed))s)")
                        self.ownToken = token
                        let pending = self.tokenContinuation!
                        self.tokenContinuation = nil
                        pending.resume(returning: token)
                        return
                    }
                    if self.tokenContinuation == nil { return } // already resumed
                }
                guard let self, let pending = self.tokenContinuation else { return }
                self.log("⏰ prepare() \(label): \(Int(seconds))s timeout — token belum datang")
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
        guard let data = Data(base64Encoded: tokenBase64) else {
            log("❌ startPeerSession: base64 decode gagal")
            return
        }
        guard let peerToken = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NIDiscoveryToken.self, from: data) else {
            log("❌ startPeerSession: NSKeyedUnarchiver gagal decode NIDiscoveryToken")
            return
        }
        guard let session = ownSession else {
            log("⚠️ startPeerSession: ownSession = nil (NISession belum dibuat atau sudah invalid)")
            return
        }

        if peerTokenMap.contains(where: { $0.userID == peerUserID && $0.token.isEqual(peerToken) }) {
            log("ℹ️ startPeerSession: token sama, skip (sudah ranging)")
            return
        }
        peerTokenMap.removeAll(where: { $0.userID == peerUserID })
        peerTokenMap.append((token: peerToken, userID: peerUserID))

        let config = NINearbyPeerConfiguration(peerToken: peerToken)
        session.run(config)
        log("✅ session.run() dipanggil — menunggu ranging... (peers=\(peerTokenMap.count))")
    }

    func stop() {
        log("🛑 NearbyInteractionService.stop()")
        ownSession?.invalidate()
        ownSession = nil
        ownToken = nil
        tokenContinuation?.resume(returning: nil)
        tokenContinuation = nil
        peerTokenMap.removeAll()
        niResults.removeAll()
        lastNIError = nil
        lastLoggedDistance.removeAll()
        onNIUpdate   = nil
        onNIRemove   = nil
        onTokenReady = nil
    }

    private func log(_ message: String) {
        UWBLogger.shared.append("[NI] \(message)")
    }
}

// MARK: - NISessionDelegate

extension NearbyInteractionService: NISessionDelegate {

    nonisolated func session(_ session: NISession,
                             didGenerateDiscoveryToken token: NIDiscoveryToken) {
        Task { @MainActor in
            guard session === self.ownSession else { return }
            self.ownToken = token
            self.log("✅ discoveryToken generated ✅")
            if let cont = self.tokenContinuation {
                self.log("▶️ resuming prepare() continuation")
                self.tokenContinuation = nil
                cont.resume(returning: token)
            } else {
                self.log("▶️ token late — memanggil onTokenReady")
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
                else {
                    self.log("⚠️ didUpdate: token tidak dikenal di peerTokenMap")
                    continue
                }
                guard let dist = object.distance.map({ Float($0) }) else {
                    self.log("⚠️ didUpdate: distance = nil")
                    continue
                }
                let distCm = dist * 100
                // Log hanya jika jarak berubah ≥ 20 cm dari log terakhir (supaya log tidak banjir)
                let prev = self.lastLoggedDistance[peerID]
                if prev == nil || abs(distCm - (prev! * 100)) >= 20 {
                    self.log(String(format: "📡 Ranging: %.0f cm", distCm))
                    self.lastLoggedDistance[peerID] = dist
                }
                self.niResults[peerID] = (dist, nil, nil)
                self.onNIUpdate?(peerID, dist, nil, nil)
            }
        }
    }

    nonisolated func session(_ session: NISession,
                             didRemove nearbyObjects: [NINearbyObject],
                             reason: NINearbyObject.RemovalReason) {
        Task { @MainActor in
            guard session === self.ownSession else { return }
            let reasonStr: String
            switch reason {
            case .peerEnded: reasonStr = "peerEnded"
            case .timeout:   reasonStr = "timeout"
            default:         reasonStr = "unknown(\(reason.rawValue))"
            }
            for object in nearbyObjects {
                guard let idx = self.peerTokenMap
                    .firstIndex(where: { $0.token.isEqual(object.discoveryToken) })
                else { continue }
                let peerID = self.peerTokenMap[idx].userID
                self.log("❌ Peer removed — reason: \(reasonStr)")
                self.peerTokenMap.remove(at: idx)
                self.niResults.removeValue(forKey: peerID)
                self.lastLoggedDistance.removeValue(forKey: peerID)
                self.onNIRemove?(peerID)
            }
        }
    }

    nonisolated func sessionWasSuspended(_ session: NISession) {
        Task { @MainActor in
            self.log("⏸ NISession suspended (app background?)")
        }
    }

    nonisolated func sessionSuspensionEnded(_ session: NISession) {
        Task { @MainActor in
            guard session === self.ownSession else { return }
            self.log("▶️ NISession resume — re-run config untuk \(self.peerTokenMap.count) peer")
            for entry in self.peerTokenMap {
                let config = NINearbyPeerConfiguration(peerToken: entry.token)
                session.run(config)
            }
            self.onTokenReady?()
        }
    }

    nonisolated func session(_ session: NISession, didInvalidateWith error: Error) {
        let errMsg = (error as NSError).localizedDescription
        let code   = (error as NSError).code
        let permDenied = (error as? NIError)?.code == .userDidNotAllow
        Task { @MainActor in
            self.lastNIError = errMsg
            self.log("❌ NISession invalid: \(errMsg) (code \(code))\(permDenied ? " — USER DID NOT ALLOW" : "")")
            if permDenied { self.isPermissionDenied = true }
            guard session === self.ownSession else { return }
            for entry in self.peerTokenMap {
                self.niResults.removeValue(forKey: entry.userID)
                self.onNIRemove?(entry.userID)
            }
            self.peerTokenMap.removeAll()
            self.lastLoggedDistance.removeAll()
            self.ownSession = nil
            self.ownToken = nil
            self.tokenContinuation?.resume(returning: nil)
            self.tokenContinuation = nil
        }
    }
}
