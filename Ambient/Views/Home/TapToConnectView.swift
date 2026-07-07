import SwiftUI

struct TapToConnectView: View {
    var isConnecting: Bool
    /// Called with the user's status string (nil if skipped).
    var onConnect: (String?) -> Void

    @State private var pulse: CGFloat = 1.0
    @State private var showStatusSheet = false
    @State private var statusText = ""

    private let circleSize: CGFloat = 160

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ZStack {
                PulseRing(baseSize: circleSize, delay: 0.0)
                PulseRing(baseSize: circleSize, delay: 0.55)
                PulseRing(baseSize: circleSize, delay: 1.1)

                Button { showStatusSheet = true } label: {
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

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.slate)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = 1.10
            }
        }
        .sheet(isPresented: $showStatusSheet) {
            StatusInputSheet(statusText: $statusText) { status in
                showStatusSheet = false
                onConnect(status)
            }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Status Input Sheet

private struct StatusInputSheet: View {
    @Binding var statusText: String
    /// Called with the status string to send, or nil to skip.
    var onDone: (String?) -> Void

    private let maxLength = 100

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("What are you up to?")
                .font(.headlineMedium)
                .padding(.top, Spacing.xl)

            ZStack(alignment: .bottomTrailing) {
                TextField("e.g. Looking to talk about startups…", text: $statusText, axis: .vertical)
                    .font(.bodyMedium)
                    .lineLimit(3...5)
                    .padding(Spacing.md)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Radius.card))
                    .onChange(of: statusText) { _, new in
                        if new.count > maxLength { statusText = String(new.prefix(maxLength)) }
                    }

                Text("\(statusText.count)/\(maxLength)")
                    .font(.labelSmall)
                    .foregroundStyle(.secondary)
                    .padding(Spacing.sm)
            }

            HStack(spacing: Spacing.md) {
                Button("Skip") { onDone(nil) }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Radius.button))

                Button("Go Online") {
                    let trimmed = statusText.trimmingCharacters(in: .whitespacesAndNewlines)
                    onDone(trimmed.isEmpty ? nil : trimmed)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.coral, in: RoundedRectangle(cornerRadius: Radius.button))
                .fontWeight(.semibold)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
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
