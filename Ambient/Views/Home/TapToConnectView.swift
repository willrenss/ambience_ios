import SwiftUI

// Shown before radar/BLE has been activated for the joined event — deliberately
// muted/desaturated to read as "offline", contrasting with the warm palette of
// the live RadarView once connected.
struct TapToConnectView: View {
    var isConnecting: Bool
    var onConnect: () -> Void

    @State private var pulse: CGFloat = 1.0

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            Button(action: onConnect) {
                ZStack {
                    Circle()
                        .fill(Color.slateLight)
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulse)
                    if isConnecting {
                        ProgressView().tint(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isConnecting)

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

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.slate)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                pulse = 1.06
            }
        }
    }
}
