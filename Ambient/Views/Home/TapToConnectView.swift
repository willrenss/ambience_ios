import SwiftUI

struct TapToConnectView: View {
    var isConnecting: Bool
    var onConnect: () -> Void

    @State private var pulse: CGFloat = 1.0

    private let circleSize: CGFloat = 160

    var body: some View {
        ZStack {
            Color.slate.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                ZStack {
                    PulseRing(baseSize: circleSize, delay: 0.0)
                    PulseRing(baseSize: circleSize, delay: 0.55)
                    PulseRing(baseSize: circleSize, delay: 1.1)

                    Button { onConnect() } label: {
                        Circle()
                            .fill(Color.slateLight)
                            .frame(width: circleSize, height: circleSize)
                            .scaleEffect(pulse)
                            .overlay {
                                if isConnecting {
                                    ProgressView().tint(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isConnecting)
                }

                VStack(spacing: Spacing.sm) {
                    Text("Tap to Connect")
                        .font(.headlineSmall)
                        .foregroundStyle(.white)
                    Text("Go online to discover people nearby and start meaningful conversations at your event.")
                        .font(.bodyMedium)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xxl)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = 1.10
            }
        }
    }
}

// MARK: - Expanding ring

private struct PulseRing: View {
    let baseSize: CGFloat
    let delay: Double

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.35

    var body: some View {
        Circle()
            .fill(Color.slateLight.opacity(opacity))
            .frame(width: baseSize, height: baseSize)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 1.65)
                    .delay(delay)
                    .repeatForever(autoreverses: false)
                ) {
                    scale = 1.85
                    opacity = 0
                }
            }
    }
}
