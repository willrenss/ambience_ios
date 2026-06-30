import SwiftUI

struct RadarView: View {
    let users: [NearbyUser]
    var selfLabel: String = "You"
    var onTapUser: ((NearbyUser) -> Void)? = nil

    @State private var sweepDeg: Double = 0
    @State private var youPulse: CGFloat = 1.0
    @State private var orbitDeg: Double = 0  // slow orbit for direction-unknown dots

    @State private var maxDistance: Float = 5.0
    @State private var baseDistance: Float = 5.0   // snapshot before each pinch gesture
    @State private var showingRange = false         // show range hud during gesture

    private static let minRange: Float = 0.5
    private static let maxRange: Float = 100.0
    private static let defaultRange: Float = 5.0

    private let ringCount = 3
    private let green = Color(red: 0.1, green: 1.0, blue: 0.4)

    var body: some View {
        GeometryReader { geo in
            let side   = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = side / 2 - 36

            ZStack {
                radarBackground(center: center, radius: radius)
                rings(center: center, radius: radius)
                crosshair(center: center, radius: radius)
                cardinalLabels(center: center, radius: radius)
                sweepView(center: center, radius: radius)
                youDot(center: center)
                userDots(center: center, radius: radius)
                rangeHUD(center: center, radius: radius)
            }
            .gesture(pinchGesture)
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    maxDistance = Self.defaultRange
                    baseDistance = Self.defaultRange
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: users) { _, newUsers in
            // Auto-expand scale so dots are never clipped at the edge
            let maxReal = newUsers.filter { $0.hasRealPosition }.map { $0.distance }.max() ?? 0
            if maxReal > maxDistance * 0.85 {
                withAnimation(.easeOut(duration: 0.5)) {
                    maxDistance = min(max(maxReal * 1.5, Self.defaultRange), Self.maxRange)
                    baseDistance = maxDistance
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                sweepDeg = 360
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                youPulse = 1.9
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                orbitDeg = 360
            }
        }
    }

    // MARK: - Pinch gesture

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                showingRange = true
                // Spread fingers (scale > 1) = zoom in = smaller range
                let newDist = baseDistance / Float(scale)
                maxDistance = min(max(newDist, Self.minRange), Self.maxRange)
            }
            .onEnded { _ in
                baseDistance = maxDistance
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.3)) { showingRange = false }
                }
            }
    }

    // MARK: - Range HUD

    private func rangeHUD(center: CGPoint, radius: CGFloat) -> some View {
        let label = maxDistance < 1
            ? String(format: "%.0f cm", maxDistance * 100)
            : String(format: maxDistance < 10 ? "%.1f m" : "%.0f m", maxDistance)
        return Text("⊙ \(label)")
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(green)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.black.opacity(0.6), in: Capsule())
            .overlay(Capsule().stroke(green.opacity(0.4), lineWidth: 0.5))
            .position(x: center.x, y: center.y + radius + 34)
            .opacity(showingRange ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: showingRange)
    }

    // MARK: - Layers

    private func radarBackground(center: CGPoint, radius: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(
                colors: [Color(white: 0.10), Color(white: 0.04)],
                center: .center, startRadius: 0, endRadius: radius
            ))
            .frame(width: radius * 2, height: radius * 2)
            .position(center)
    }

    private func rings(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(1...ringCount, id: \.self) { ring in
            let r = radius * CGFloat(ring) / CGFloat(ringCount)
            ZStack {
                Circle()
                    .stroke(green.opacity(0.22), lineWidth: 1)
                    .blur(radius: 0.5)
                    .frame(width: r * 2, height: r * 2)

                Text(ringLabel(ring: ring))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(green.opacity(0.45))
                    .offset(x: r + 10, y: -5)
            }
            .position(center)
        }
    }

    private func crosshair(center: CGPoint, radius: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: center.x, y: center.y - radius))
            p.addLine(to: CGPoint(x: center.x, y: center.y + radius))
            p.move(to: CGPoint(x: center.x - radius, y: center.y))
            p.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        }
        .stroke(green.opacity(0.12), lineWidth: 0.5)
    }

    private func cardinalLabels(center: CGPoint, radius: CGFloat) -> some View {
        // Heading-up radar: top = direction phone is facing. Single arrow to make it clear.
        ZStack {
            Text("▲")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(green.opacity(0.85))
                .position(x: center.x, y: center.y - radius - 16)
        }
    }

    private func sweepView(center: CGPoint, radius: CGFloat) -> some View {
        let angleRad = (sweepDeg - 90) * .pi / 180
        return ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        stops: [
                            .init(color: .clear,              location: 0.00),
                            .init(color: .clear,              location: 0.65),
                            .init(color: green.opacity(0.08), location: 0.82),
                            .init(color: green.opacity(0.35), location: 0.99),
                            .init(color: green.opacity(0.35), location: 1.00),
                        ],
                        center: .center
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
                .position(center)
                .rotationEffect(.degrees(sweepDeg - 90))
                .blendMode(.screen)

            Path { p in
                p.move(to: center)
                p.addLine(to: CGPoint(
                    x: center.x + radius * CGFloat(cos(angleRad)),
                    y: center.y + radius * CGFloat(sin(angleRad))
                ))
            }
            .stroke(green.opacity(0.85), lineWidth: 1.5)
            .blur(radius: 0.8)
        }
    }

    private func youDot(center: CGPoint) -> some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                .frame(width: 36 * youPulse, height: 36 * youPulse)
                .opacity(Double(2.4 - youPulse) / 1.4)

            Circle()
                .fill(Color.accentColor)
                .frame(width: 12, height: 12)
                .shadow(color: .accentColor, radius: 4)

            Text(String(selfLabel.prefix(1)))
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white)
        }
        .position(center)
    }

    private func userDots(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
            let (pos, hasDir) = dotInfo(for: user, index: index, center: center, radius: radius)
            UserDotView(user: user, green: green, directionKnown: hasDir)
                .position(pos)
                .animation(hasDir
                    ? .spring(response: 0.45, dampingFraction: 0.72)
                    : .linear(duration: 0),   // orbit driven by @State, no spring fighting it
                    value: pos)
                .onTapGesture { onTapUser?(user) }
        }
    }

    // MARK: - Helpers

    private func ringLabel(ring: Int) -> String {
        let m = maxDistance * Float(ring) / Float(ringCount)
        return m < 1 ? String(format: "%.0fcm", m * 100) : String(format: "%.0fm", m)
    }

    // Returns (position, hasRealDirection)
    private func dotInfo(for user: NearbyUser, index: Int, center: CGPoint, radius: CGFloat)
        -> (CGPoint, Bool)
    {
        let offset = Double(index) * (2.0 * .pi / Double(max(users.count, 1)))
        let angle  = (orbitDeg * .pi / 180) + offset

        // No position yet — orbit near the outer ring so user knows someone is nearby
        if !user.hasRealPosition {
            let r = radius * 0.88
            return (CGPoint(x: center.x + sin(angle) * r,
                            y: center.y - cos(angle) * r), false)
        }

        let norm = CGFloat(min(user.distance / maxDistance, 1.0))
        if let d = user.direction {
            // Real UWB direction — precise position
            return (CGPoint(x: center.x + sin(CGFloat(d)) * norm * radius,
                            y: center.y - cos(CGFloat(d)) * norm * radius), true)
        } else {
            // Position known but direction unknown — orbit at correct distance ring
            return (CGPoint(x: center.x + sin(angle) * norm * radius,
                            y: center.y - cos(angle) * norm * radius), false)
        }
    }
}

// MARK: - User dot

private struct UserDotView: View {
    let user: NearbyUser
    let green: Color
    let directionKnown: Bool
    @State private var appeared = false
    @State private var locatingPulse: CGFloat = 1.0

    private var isLocating: Bool { !user.hasRealPosition }

    private var distLabel: String {
        if isLocating { return "~" }
        let dist = formatDist(user.distance)
        switch user.distanceSource {
        case .uwb:     return "⊙ \(dist)"   // dot = UWB
        case .gps:     return "⌖ \(dist)"   // crosshair = GPS
        case .unknown: return "~"
        }
    }

    private var labelColor: Color {
        switch user.distanceSource {
        case .uwb:     return green
        case .gps:     return Color.yellow.opacity(0.85)
        case .unknown: return Color.yellow.opacity(0.8)
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // Glow
                Circle()
                    .fill(green.opacity(isLocating ? 0.06 : directionKnown ? 0.18 : 0.10))
                    .frame(width: 48, height: 48)
                    .blur(radius: 8)
                    .scaleEffect(isLocating ? locatingPulse : 1)

                // Dot
                Circle()
                    .fill(isLocating ? Color.clear : directionKnown ? green : green.opacity(0.5))
                    .frame(width: 32, height: 32)
                    .shadow(color: green.opacity(isLocating ? 0.2 : directionKnown ? 0.9 : 0.4), radius: 6)
                    .overlay(
                        Circle()
                            .stroke(
                                isLocating ? Color.yellow.opacity(0.7) : green.opacity(directionKnown ? 0 : 0.6),
                                style: StrokeStyle(lineWidth: 1.5, dash: isLocating ? [4, 3] : [])
                            )
                            .frame(width: 32, height: 32)
                    )

                Text(String(user.displayName.prefix(1)))
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(isLocating ? Color.yellow.opacity(0.7) : directionKnown ? Color.black : Color.black.opacity(0.5))
            }
            .overlay(alignment: .topTrailing) {
                if isLocating {
                    // Scanning indicator
                    Image(systemName: "location.slash")
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(2)
                        .background(Color.yellow.opacity(0.75), in: Circle())
                        .offset(x: 4, y: -4)
                } else if !directionKnown {
                    Text("?")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(2)
                        .background(Color.orange.opacity(0.8), in: Circle())
                        .offset(x: 4, y: -4)
                }
            }

            Text(distLabel)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(labelColor)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.black.opacity(0.65), in: Capsule())
                .overlay(Capsule().stroke(labelColor.opacity(0.3), lineWidth: 0.5))
        }
        .scaleEffect(appeared ? 1 : 0.3)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { appeared = true }
            if isLocating {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    locatingPulse = 1.6
                }
            }
        }
    }

    private func formatDist(_ m: Float) -> String {
        if m < 1.0 { return String(format: "%.0fcm", m * 100) }
        return String(format: "%.1fm", m)
    }
}
