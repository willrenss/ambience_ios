import SwiftUI

struct RadarView: View {
    let users: [NearbyUser]
    var onTapUser: ((NearbyUser) -> Void)? = nil

    @State private var orbitDeg: Double = 0  // slow orbit for direction-unknown dots
    @State private var pulse: CGFloat = 1.0

    private let maxDistance: Float = 15.0

    var body: some View {
        GeometryReader { geo in
            let side   = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = max(side / 2 - 24, 1)

            ZStack {
                ringOutlines(center: center, radius: radius)
                softRings(center: center, radius: radius)
                youDot(center: center)
                statusLabel(center: center, radius: radius)
                userDots(center: center, radius: radius)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                orbitDeg = 360
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = 1.12
            }
        }
    }

    // MARK: - Background layers

    // Faint full-bleed circle outlines, per the reference design.
    private func ringOutlines(center: CGPoint, radius: CGFloat) -> some View {
        ForEach([1.0, 1.6, 2.3], id: \.self) { multiplier in
            Circle()
                .stroke(Color.terracotta.opacity(0.12), lineWidth: 1)
                .frame(width: radius * 2 * multiplier, height: radius * 2 * multiplier)
                .position(center)
        }
    }

    // Layered soft-peach filled circles, increasingly saturated toward the center.
    private func softRings(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(Array(zip([1.0, 0.72, 0.46, 0.24], [0.18, 0.28, 0.4, 0.55])), id: \.0) { scale, opacity in
            Circle()
                .fill(Color.apricot.opacity(opacity))
                .frame(width: radius * 2 * scale, height: radius * 2 * scale)
                .position(center)
        }
    }

    private func youDot(center: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 0, endRadius: 40))
                .frame(width: 80, height: 80)
                .scaleEffect(pulse)
            Circle()
                .fill(.white)
                .frame(width: 26, height: 26)
                .shadow(color: Color.terracotta.opacity(0.25), radius: 6)
        }
        .position(center)
    }

    private func statusLabel(center: CGPoint, radius: CGFloat) -> some View {
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
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: pos)
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
            return CGPoint(x: center.x + sin(CGFloat(d)) * norm * radius,
                           y: center.y - cos(CGFloat(d)) * norm * radius)
        }
        let r = max(norm, 0.35) * radius
        return CGPoint(x: center.x + sin(angle) * r, y: center.y - cos(angle) * r)
    }
}

// Solid coral avatar bubble with the person's initial, per the reference design.
private struct RadarBlip: View {
    let user: NearbyUser

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.coral)
                .frame(width: 48, height: 48)
                .shadow(color: Color.terracotta.opacity(0.3), radius: 6, y: 2)
            Text(String(user.nickname.prefix(1)).uppercased())
                .font(.titleMedium)
                .foregroundStyle(.white)
        }
    }
}
