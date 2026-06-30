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
    }
}
