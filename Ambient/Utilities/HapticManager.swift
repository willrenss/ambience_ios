import CoreHaptics
import UIKit

// Core Haptics engine kept alive for the radar session lifetime, with pre-built
// cached pattern players per the spec. Falls back to UIFeedbackGenerator when the
// device has no Taptic Engine support.
@MainActor
final class HapticManager {
    static let shared = HapticManager()

    enum Pattern {
        case receivePing   // two strong pulses, intensity 1.0, sharpness 0.8, ~100ms gap
        case sendPing      // single strong pulse, intensity 1.0, sharpness 0.8
        case mutualMatch   // three strong pulses, intensity 1.0, sharpness 0.8, ~100ms gaps
        case error         // three short fast pulses, intensity 0.5, sharpness 0.9
    }

    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private var players: [Pattern: CHHapticPatternPlayer] = [:]

    private init() {}

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "haptics_enabled") as? Bool ?? true
    }

    // Build the engine once and cache all four players. Call when radar arms.
    func startEngine() {
        guard supportsHaptics, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = false
            engine.resetHandler = { [weak self] in
                // Engine reset (e.g. returning from background) — restart and rebuild players.
                try? self?.engine?.start()
                self?.rebuildPlayers()
            }
            engine.stoppedHandler = { _ in }
            try engine.start()
            self.engine = engine
            rebuildPlayers()
        } catch {
            self.engine = nil
        }
    }

    func stopEngine() {
        engine?.stop(completionHandler: nil)
        engine = nil
        players.removeAll()
    }

    func play(_ pattern: Pattern) {
        guard isEnabled else { return }
        guard supportsHaptics, let player = players[pattern] else {
            playFallback(pattern)
            return
        }
        do {
            try engine?.start()   // no-op if already running
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            playFallback(pattern)
        }
    }

    // MARK: - Pattern building

    private func rebuildPlayers() {
        guard let engine else { return }
        players.removeAll()
        for pattern in [Pattern.receivePing, .sendPing, .mutualMatch, .error] {
            if let built = try? engine.makePlayer(with: chPattern(for: pattern)) {
                players[pattern] = built
            }
        }
    }

    private func event(_ time: TimeInterval, intensity: Float, sharpness: Float,
                       duration: TimeInterval? = nil) -> CHHapticEvent {
        let params = [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ]
        if let duration {
            return CHHapticEvent(eventType: .hapticContinuous, parameters: params,
                                 relativeTime: time, duration: duration)
        }
        return CHHapticEvent(eventType: .hapticTransient, parameters: params, relativeTime: time)
    }

    private func chPattern(for pattern: Pattern) throws -> CHHapticPattern {
        switch pattern {
        case .receivePing:
            return try CHHapticPattern(events: [
                event(0.0, intensity: 1.0, sharpness: 0.8),
                event(0.1, intensity: 1.0, sharpness: 0.8)
            ], parameters: [])
        case .sendPing:
            return try CHHapticPattern(events: [
                event(0, intensity: 1.0, sharpness: 0.8)
            ], parameters: [])
        case .mutualMatch:
            return try CHHapticPattern(events: [
                event(0.0, intensity: 1.0, sharpness: 0.8),
                event(0.1, intensity: 1.0, sharpness: 0.8),
                event(0.2, intensity: 1.0, sharpness: 0.8)
            ], parameters: [])
        case .error:
            return try CHHapticPattern(events: [
                event(0.00, intensity: 0.5, sharpness: 0.9),
                event(0.08, intensity: 0.5, sharpness: 0.9),
                event(0.16, intensity: 0.5, sharpness: 0.9)
            ], parameters: [])
        }
    }

    // MARK: - Fallback (no Taptic Engine)

    private func playFallback(_ pattern: Pattern) {
        switch pattern {
        case .receivePing:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .sendPing:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .mutualMatch:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
