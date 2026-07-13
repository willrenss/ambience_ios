import SwiftUI

struct RadarView: View {
    let users: [NearbyUser]
    var onTapUser: ((NearbyUser) -> Void)? = nil

    @State private var orbitDeg: Double   = 0    // slow orbit for direction-unknown dots
    @State private var sweepAngle: Double = 0    // radar sweep rotation (0→360)

    // Scale dynamically so all users stay visible; minimum 20 m for BLE context.
    private var maxDistance: Float {
        let d = users.filter { $0.hasRealPosition }.map { $0.distance }.max() ?? 0
        return max(d * 1.25, 20.0)
    }

    var body: some View {
        GeometryReader { geo in
            let side   = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = max(side / 2 - 24, 1)

            ZStack {
                ringOutlines(center: center, radius: radius)
                softRings(center: center, radius: radius)
                sweepLayer(center: center, radius: radius)
                pulseRings(center: center)
                youDot(center: center)
                statusLabel(center: center)
                userDots(center: center, radius: radius)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                orbitDeg = 360
            }
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                sweepAngle = 360
            }
        }
    }

    // MARK: - Background layers

    private func ringOutlines(center: CGPoint, radius: CGFloat) -> some View {
        ForEach([1.0, 1.6, 2.3], id: \.self) { multiplier in
            Circle()
                .stroke(Color.terracotta.opacity(0.12), lineWidth: 1)
                .frame(width: radius * 2 * multiplier, height: radius * 2 * multiplier)
                .position(center)
        }
    }

    private func softRings(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(Array(zip([1.0, 0.72, 0.46, 0.24], [0.18, 0.28, 0.4, 0.55])), id: \.0) { scale, opacity in
            Circle()
                .fill(Color.apricot.opacity(opacity))
                .frame(width: radius * 2 * scale, height: radius * 2 * scale)
                .position(center)
        }
    }

    // Rotating radar sweep: a 60° semi-transparent sector with a bright leading edge.
    // Geometry is drawn once at rest (pointing north) in a local frame, then spun
    // with `.rotationEffect` — a plain `Path` has no `animatableData`, so animating
    // its angles directly (the old approach) just snapped once per loop instead of
    // visibly rotating; `.rotationEffect` is what SwiftUI can actually interpolate.
    private func sweepLayer(center: CGPoint, radius: CGFloat) -> some View {
        let local = CGPoint(x: radius, y: radius)
        return ZStack {
            Path { path in
                path.move(to: local)
                path.addArc(center: local, radius: radius,
                            startAngle: .degrees(-90 - 60),
                            endAngle:   .degrees(-90),
                            clockwise: false)
                path.closeSubpath()
            }
            .fill(Color.terracotta.opacity(0.13))

            Path { path in
                path.move(to: local)
                path.addLine(to: CGPoint(x: local.x, y: local.y - radius))
            }
            .stroke(Color.terracotta.opacity(0.55), lineWidth: 1.5)
        }
        .frame(width: radius * 2, height: radius * 2)
        .rotationEffect(.degrees(sweepAngle))
        .position(center)
    }

    // Expanding pulse rings from center — same pattern as the offline Tap to Connect screen.
    private func pulseRings(center: CGPoint) -> some View {
        ZStack {
            RadarPulseRing(baseSize: 60, color: Color.terracotta, delay: 0.0)
                .position(center)
            RadarPulseRing(baseSize: 60, color: Color.terracotta, delay: 0.7)
                .position(center)
            RadarPulseRing(baseSize: 60, color: Color.terracotta, delay: 1.4)
                .position(center)
        }
    }

    private func youDot(center: CGPoint) -> some View {
        Circle()
            .fill(.white)
            .frame(width: 26, height: 26)
            .shadow(color: Color.terracotta.opacity(0.3), radius: 8)
            .position(center)
    }

    private func statusLabel(center: CGPoint) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 18, weight: .semibold))
            Text("Finding Nearby")
                .font(.titleSmall)
        }
        .foregroundStyle(Color.terracotta.opacity(0.8))
        .position(x: center.x, y: center.y + 90)
    }

    // MARK: - Blips

    private func userDots(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
            let pos = dotPosition(for: user, index: index, center: center, radius: radius)
            RadarBlip(user: user)
                .position(pos)
                .animation(.spring(response: 0.7, dampingFraction: 0.65), value: pos)
                .onTapGesture { onTapUser?(user) }
        }
    }

    private func dotPosition(for user: NearbyUser, index: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let offset = Double(index) * (2.0 * .pi / Double(max(users.count, 1)))
        let angle  = (orbitDeg * .pi / 180) + offset

        if !user.hasRealPosition {
            let r = radius * 0.8
            return CGPoint(x: center.x + sin(angle) * r, y: center.y - cos(angle) * r)
        }

        let norm = CGFloat(min(user.distance / maxDistance, 1.0))
        if let d = user.direction {
            // GPS-derived bearing relative to device heading.
            // Negate sin so clockwise bearing maps to right on screen (SwiftUI X-axis
            // is left→right, which is opposite to the mathematical right-hand convention
            // where positive angles rotate counterclockwise).
            return CGPoint(x: center.x - sin(CGFloat(d)) * norm * radius,
                           y: center.y - cos(CGFloat(d)) * norm * radius)
        }
        // No direction — orbit at proportional radius
        let r = max(norm, 0.35) * radius
        return CGPoint(x: center.x + sin(angle) * r, y: center.y - cos(angle) * r)
    }
}

// MARK: - Blip bubble

private struct RadarBlip: View {
    let user: NearbyUser

    var body: some View {
        VStack(spacing: 4) {
            // Avatar
            ZStack {
                if let urlStr = user.photoURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.coral)
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.coral)
                        .frame(width: 48, height: 48)
                    Text(String(user.nickname.prefix(1)).uppercased())
                        .font(.titleMedium)
                        .foregroundStyle(.white)
                }
            }
            .shadow(color: Color.terracotta.opacity(0.3), radius: 6, y: 2)

            // Distance badge
            Text(user.distanceLabel)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.black.opacity(0.45), in: Capsule())
        }
    }
}

// MARK: - Expanding pulse ring (matches TapToConnectView's PulseRing style)

private struct RadarPulseRing: View {
    let baseSize: CGFloat
    let color: Color
    let delay: Double

    @State private var scale: CGFloat  = 1.0
    @State private var opacity: Double = 0.4

    var body: some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: baseSize, height: baseSize)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 2.0)
                    .delay(delay)
                    .repeatForever(autoreverses: false)
                ) {
                    scale   = 4.5  // expands to ~270 px from 60 px base
                    opacity = 0
                }
            }
    }
}
