import NearbyInteraction
import Foundation

@MainActor
final class NearbyInteractionService: NSObject {
    static let shared = NearbyInteractionService()

    private var ownSession: NISession?
    private(set) var ownToken: NIDiscoveryToken?
    private var tokenContinuation: CheckedContinuation<NIDiscoveryToken?, Never>?

    private var peerSessions: [UUID: NISession] = [:]
    private(set) var niResults: [UUID: (distance: Float, direction: Float?)] = [:]
    private var lastNIError: String? = nil

    // Typed callbacks — data is passed directly so callers don't need a MainActor hop
    // to re-read niResults. Called on MainActor; callers Task-hop to their own actor.
    var onNIUpdate:    (@Sendable (_ peerID: UUID, _ distance: Float, _ direction: Float?) -> Void)?
    var onNIRemove:    (@Sendable (_ peerID: UUID) -> Void)?
    // Fires when token arrives AFTER prepare() already timed out, so caller can re-upload presence
    var onTokenReady:  (@Sendable () -> Void)?

    private override init() { super.init() }

    // MARK: - Own session

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
        var s = "UWB:\(dirCap) \(tok) s=\(peerSessions.count) [\(details)]"
        if let err = lastNIError { s += " ⚠️\(err)" }
        return s
    }

    func prepare() async -> NIDiscoveryToken? {
        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
            return nil
        }
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
        guard peerSessions[peerUserID] == nil,
              let data = Data(base64Encoded: tokenBase64),
              let peerToken = try? NSKeyedUnarchiver.unarchivedObject(
                  ofClass: NIDiscoveryToken.self, from: data)
        else { return }

        let session = NISession()
        session.delegate = self
        peerSessions[peerUserID] = session
        session.run(NINearbyPeerConfiguration(peerToken: peerToken))
    }

    func stop() {
        ownSession?.invalidate()
        ownSession = nil
        ownToken = nil
        tokenContinuation?.resume(returning: nil)
        tokenContinuation = nil
        peerSessions.values.forEach { $0.invalidate() }
        peerSessions.removeAll()
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
            guard let peerID = self.peerSessions.first(where: { $0.value === session })?.key,
                  let object = nearbyObjects.first else { return }

            let dist = object.distance.map { Float($0) }
                ?? self.niResults[peerID]?.distance ?? 1.0

            let bearing: Float? = object.direction.map { dir in
                Float(atan2(Double(dir.x), Double(-dir.z)))
            }
            self.niResults[peerID] = (dist, bearing)
            // Pass data directly — no caller needs to re-read niResults via MainActor hop
            self.onNIUpdate?(peerID, dist, bearing)
        }
    }

    nonisolated func session(_ session: NISession,
                             didRemove nearbyObjects: [NINearbyObject],
                             reason: NINearbyObject.RemovalReason) {
        Task { @MainActor in
            guard let peerID = self.peerSessions.first(where: { $0.value === session })?.key
            else { return }
            self.niResults.removeValue(forKey: peerID)
            self.onNIRemove?(peerID)
        }
    }

    nonisolated func session(_ session: NISession, didInvalidateWith error: Error) {
        let errMsg = (error as NSError).localizedDescription
        Task { @MainActor in
            self.lastNIError = errMsg
            guard let peerID = self.peerSessions.first(where: { $0.value === session })?.key
            else { return }
            self.peerSessions.removeValue(forKey: peerID)
            self.niResults.removeValue(forKey: peerID)
            self.onNIRemove?(peerID)
        }
    }
}
