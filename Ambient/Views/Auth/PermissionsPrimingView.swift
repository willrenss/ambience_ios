import SwiftUI

// Shown once, right after account creation. Each step explains *why* we need
// a permission before the system dialog appears (priming), then triggers the
// real OS prompt on tap. Location and Bluetooth are required to continue;
// Notifications alone is skippable per the mockup.
struct PermissionsPrimingView: View {
    @Environment(AppState.self) private var appState
    @State private var step: Int = 0
    private let stepCount = 3

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Spacing.xxxl)

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(title)
                    .font(.headlineSmall)
                    .foregroundStyle(Color.terracotta)
                Text(subtitle)
                    .font(.bodyMedium)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)

            Spacer()

            illustration
                .frame(height: 260)
                .frame(maxWidth: .infinity)

            Spacer()

            actions
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
        }
        .background(Color.peach.opacity(0.35).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    // MARK: - Step content

    private var title: String {
        switch step {
        case 0: return "Enable GPS"
        case 1: return "Enable Bluetooth"
        default: return "Stay Notified"
        }
    }

    private var subtitle: String {
        switch step {
        case 0: return "We map your local surroundings to find active events near you. To keep your radar scanning seamlessly — we need your location set to Always Allow."
        case 1: return "Your phone talks to nearby devices using Bluetooth and Ultra-Wideband signals. This enables your device to measure the exact distance of people right in front of you."
        default: return "When someone nearby drops a ping to connect with you, your phone will vibrate, play a custom sound, and notify you instantly. Turn on notifications so you never miss an opportunity to meet."
        }
    }

    @ViewBuilder
    private var illustration: some View {
        ZStack {
            Circle()
                .fill(Color.apricot.opacity(0.35))
                .frame(width: 200, height: 200)
            Image(systemName: symbolName)
                .font(.system(size: 84, weight: .light))
                .foregroundStyle(Color.coral)
        }
    }

    private var symbolName: String {
        switch step {
        case 0: return "location.circle.fill"
        case 1: return "dot.radiowaves.left.and.right"
        default: return "bell.badge.fill"
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        switch step {
        case 0:
            Button("Allow Location Access") {
                Task {
                    await LocationService.shared.requestPermissionAndStart()
                    advance()
                }
            }
            .buttonStyle(PrimaryButtonStyle())

        case 1:
            Button("Allow Bluetooth Access") {
                BluetoothPermissionPrimer.shared.request()
                advance()
            }
            .buttonStyle(PrimaryButtonStyle())

        default:
            HStack(spacing: Spacing.md) {
                Button("Skip") { finish() }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Enable") {
                    Task {
                        _ = await NotificationPermissionPrimer.request()
                        finish()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func advance() {
        if step < stepCount - 1 {
            step += 1
        } else {
            finish()
        }
    }

    private func finish() {
        appState.hasSeenPermissionsPriming = true
    }
}
