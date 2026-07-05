<<<<<<< HEAD
import UIKit
import AudioToolbox

// UIFeedbackGenerator is simpler and more reliable than CHHapticEngine:
// no AudioConverter dependency, no engine startup, works immediately.
// All methods must be called on the main thread (callers are @MainActor).
final class HapticManager: Sendable {
    static let shared = HapticManager()
    private init() {}

    /// Three soft pulses 300 ms apart.
    @MainActor func playMatchHaptic() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { gen.impactOccurred() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) { gen.impactOccurred() }
    }

    @MainActor func playSuccessHaptic() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }

    /// Strong triple-buzz + ping sound — "someone pinged you".
    @MainActor func playWaveHaptic() {
        AudioServicesPlaySystemSound(1057)   // sonar ping sound

        // Fire immediately — each prepare()+impact pair in sequence so engine stays warm
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.prepare(); gen.impactOccurred(intensity: 1.0)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            gen.prepare(); gen.impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            gen.prepare(); gen.impactOccurred(intensity: 1.0)
        }
    }

    @MainActor func playLightTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
=======
import CoreHaptics
import UIKit

// Core Haptics engine kept alive for the radar session lifetime, with pre-built
// cached pattern players per the spec. Falls back to UIFeedbackGenerator when the
// device has no Taptic Engine support.
@MainActor
final class HapticManager {
    static let shared = HapticManager()

    enum Pattern {
        case receivePing   // single pulse, intensity 0.6, sharpness 0.4
        case sendPing      // very short pulse, intensity 0.4, sharpness 0.8
        case mutualMatch   // two pulses 0.7 then 1.0, ~100ms gap
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
                event(0, intensity: 0.6, sharpness: 0.4)
            ], parameters: [])
        case .sendPing:
            return try CHHapticPattern(events: [
                event(0, intensity: 0.4, sharpness: 0.8)
            ], parameters: [])
        case .mutualMatch:
            return try CHHapticPattern(events: [
                event(0.0,  intensity: 0.7, sharpness: 0.5),
                event(0.1,  intensity: 1.0, sharpness: 0.6)   // ~100ms gap
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
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .sendPing:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .mutualMatch:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
>>>>>>> c5f4022 (Iniatial Commit)
    }
}
