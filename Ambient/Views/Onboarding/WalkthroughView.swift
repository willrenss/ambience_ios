import SwiftUI

// MARK: - Slide data

private struct WalkthroughSlide {
    let title: String
    let subtitle: String
}

private let slides: [WalkthroughSlide] = [
    WalkthroughSlide(
        title: "Tell Us What You Love",
        subtitle: "Select your favorite interests and add your unique hobbies. This helps us customize your map and ensure you discover events and people that truly match your vibe."
    ),
    WalkthroughSlide(
        title: "Explore Social Events Nearby",
        subtitle: "Browse our live map to see trending events, gatherings, and festivals happening right around you, curated directly from social media. Find where the action is and head over."
    ),
    WalkthroughSlide(
        title: "Unlock Your Social Radar",
        subtitle: "Once you arrive at the event venue, your Social Radar automatically activates! Scan the room, see active users nearby, and send a real-time ping to connect instantly."
    ),
]

// MARK: - WalkthroughView

struct WalkthroughView: View {
    let onDone: () -> Void
    @State private var currentPage = 0

    var body: some View {
        ZStack(alignment: .top) {
            Color.coral.ignoresSafeArea()

            VStack(spacing: 0) {
                // Back button row
                HStack {
                    if currentPage > 0 {
                        Button {
                            withAnimation(.spring(duration: 0.35)) { currentPage -= 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.primary)
                                .frame(width: 38, height: 38)
                                .background(.white.opacity(0.9), in: Circle())
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .animation(.spring(duration: 0.3), value: currentPage)

                // Illustration card
                illustrationCard
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.lg)
                    .frame(maxHeight: .infinity)

                // White bottom sheet
                bottomSheet
            }
        }
    }

    // MARK: - Illustration card

    private var illustrationCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: 0x2E2318))

            Group {
                switch currentPage {
                case 0: InterestsIllustration()
                case 1: EventsIllustration()
                default: RadarIllustration()
                }
            }
            .id(currentPage)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: currentPage)
        }
    }

    // MARK: - Bottom sheet

    private var bottomSheet: some View {
        VStack(spacing: 0) {
            VStack(spacing: Spacing.md) {
                Text(slides[currentPage].title)
                    .font(.headlineSmall)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .id("t\(currentPage)")
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: currentPage)

                Text(slides[currentPage].subtitle)
                    .font(.bodySmall)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.primary.opacity(0.55))
                    .lineSpacing(4)
                    .id("s\(currentPage)")
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: currentPage)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xl)

            Spacer(minLength: Spacing.xl)

            navRow
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, 44)
        }
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32)
                .fill(.white)
        )
        .frame(minHeight: 240)
    }

    // MARK: - Nav row

    private var navRow: some View {
        HStack(spacing: 0) {
            Button { onDone() } label: {
                Text("Skip")
                    .font(.labelLarge)
                    .foregroundStyle(Color.primary.opacity(0.6))
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(Color.primary.opacity(0.07), in: Capsule())
            }

            Spacer()

            HStack(spacing: 7) {
                ForEach(0..<slides.count, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? Color.terracotta : Color.primary.opacity(0.2))
                        .frame(width: i == currentPage ? 18 : 8, height: 8)
                        .animation(.spring(duration: 0.3), value: currentPage)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.primary.opacity(0.07), in: Capsule())

            Spacer()

            Button {
                withAnimation(.spring(duration: 0.35)) {
                    if currentPage < slides.count - 1 { currentPage += 1 } else { onDone() }
                }
            } label: {
                Text(currentPage < slides.count - 1 ? "Next" : "Start")
                    .font(.labelLarge)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(Color.coral, in: Capsule())
            }
        }
    }
}

// MARK: - Illustration 1: Interests

private struct InterestItem {
    let icon: String
    let color: Color
    let label: String
}

private struct InterestsIllustration: View {
    private let items: [InterestItem] = [
        InterestItem(icon: "music.note",          color: Color(hex: 0xBB86FC), label: "Music"),
        InterestItem(icon: "heart.fill",           color: Color(hex: 0xFF6B8A), label: "Love"),
        InterestItem(icon: "camera.fill",          color: Color(hex: 0x64B5F6), label: "Photo"),
        InterestItem(icon: "gamecontroller.fill",  color: Color(hex: 0x81C784), label: "Gaming"),
        InterestItem(icon: "book.fill",            color: Color(hex: 0xFFB74D), label: "Books"),
        InterestItem(icon: "fork.knife",           color: Color(hex: 0xFF8A65), label: "Food"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Your Interests")
                .font(.labelMedium)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.bottom, Spacing.lg)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: Spacing.lg
            ) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(item.color.opacity(0.18))
                                .frame(width: 60, height: 60)
                            Image(systemName: item.icon)
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(item.color)
                        }
                        Text(item.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.coral.opacity(0.8))
                Text("Add more hobbies")
                    .font(.labelSmall)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.bottom, Spacing.xl)
        }
    }
}

// MARK: - Illustration 2: Events / Map

private struct MapEventItem {
    let icon: String
    let color: Color
    let label: String
}

private struct EventsIllustration: View {
    private let leftCol: [MapEventItem] = [
        MapEventItem(icon: "music.mic",       color: Color(hex: 0xBB86FC), label: "Concert"),
        MapEventItem(icon: "figure.dance",    color: Color(hex: 0xFF6B8A), label: "Party"),
    ]
    private let rightCol: [MapEventItem] = [
        MapEventItem(icon: "paintbrush.fill", color: Color(hex: 0x64B5F6), label: "Art Fair"),
        MapEventItem(icon: "sportscourt.fill", color: Color(hex: 0x81C784), label: "Sports"),
    ]
    private let centerItem = MapEventItem(icon: "fork.knife", color: Color(hex: 0xFF8A65), label: "Food Fest")

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                GridLines()

                VStack(spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(Array(leftCol.enumerated()), id: \.offset) { _, item in
                            MapPin(item: item)
                        }
                        Spacer()
                        ForEach(Array(rightCol.enumerated()), id: \.offset) { _, item in
                            MapPin(item: item)
                        }
                    }
                    MapPin(item: centerItem)
                }
                .padding(.horizontal, Spacing.xl)

                // "You are here" pulse
                Circle()
                    .fill(Color.coral)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.coral.opacity(0.3), lineWidth: 7))
            }
            .frame(maxWidth: .infinity)

            Spacer()

            HStack(spacing: 6) {
                Circle().fill(Color(hex: 0x81C784)).frame(width: 8, height: 8)
                Text("Live events near you")
                    .font(.labelSmall)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.bottom, Spacing.xl)
        }
    }
}

private struct MapPin: View {
    let item: MapEventItem

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(item.color.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: item.icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(item.color)
            }
            Rectangle()
                .fill(item.color.opacity(0.5))
                .frame(width: 2, height: 7)
            Circle()
                .fill(item.color.opacity(0.5))
                .frame(width: 5, height: 5)
            Text(item.label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

private struct GridLines: View {
    var body: some View {
        Canvas { ctx, size in
            let cols = 6, rows = 8
            let colW = size.width / CGFloat(cols)
            let rowH = size.height / CGFloat(rows)
            var path = Path()
            for c in 0...cols {
                let x = CGFloat(c) * colW
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for r in 0...rows {
                let y = CGFloat(r) * rowH
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 1)
        }
    }
}

// MARK: - Illustration 3: Radar

private struct RadarBlip: Identifiable {
    let id: String
    let angle: Double
    let radius: CGFloat
    let color: Color
}

private struct RadarIllustration: View {
    @State private var pulse = false
    @State private var sweepAngle: Double = 0

    private let blips: [RadarBlip] = [
        RadarBlip(id: "A", angle: 20,  radius: 0.55, color: Color(hex: 0xFF6B8A)),
        RadarBlip(id: "B", angle: 85,  radius: 0.72, color: Color(hex: 0xBB86FC)),
        RadarBlip(id: "C", angle: 145, radius: 0.48, color: Color(hex: 0x64B5F6)),
        RadarBlip(id: "D", angle: 210, radius: 0.65, color: Color(hex: 0x81C784)),
        RadarBlip(id: "E", angle: 285, radius: 0.58, color: Color(hex: 0xFFB74D)),
        RadarBlip(id: "F", angle: 340, radius: 0.76, color: Color(hex: 0xFF8A65)),
    ]

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let maxR = min(geo.size.width, geo.size.height) * 0.42

            ZStack {
                // Concentric rings
                ForEach([1.0, 0.67, 0.33], id: \.self) { f in
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                        .frame(width: maxR * 2 * f, height: maxR * 2 * f)
                }

                // Radar sweep
                Circle()
                    .trim(from: 0, to: 0.22)
                    .fill(
                        AngularGradient(
                            colors: [Color.coral.opacity(0.3), .clear],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(80)
                        )
                    )
                    .frame(width: maxR * 2, height: maxR * 2)
                    .rotationEffect(.degrees(sweepAngle))
                    .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: sweepAngle)

                // Cross hairs
                Path { path in
                    path.move(to: CGPoint(x: cx, y: cy - maxR))
                    path.addLine(to: CGPoint(x: cx, y: cy + maxR))
                    path.move(to: CGPoint(x: cx - maxR, y: cy))
                    path.addLine(to: CGPoint(x: cx + maxR, y: cy))
                }
                .stroke(.white.opacity(0.08), lineWidth: 1)
                .frame(width: geo.size.width, height: geo.size.height)

                // User blips
                ForEach(blips) { blip in
                    let rad = blip.angle * .pi / 180
                    let dist = maxR * blip.radius
                    ZStack {
                        Circle()
                            .fill(blip.color.opacity(0.22))
                            .frame(width: 34, height: 34)
                        Text(blip.id)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(blip.color)
                    }
                    .position(
                        x: cx + dist * cos(rad),
                        y: cy + dist * sin(rad)
                    )
                }

                // Center YOU dot
                ZStack {
                    Circle()
                        .fill(Color.coral.opacity(0.22))
                        .frame(width: 48, height: 48)
                        .scaleEffect(pulse ? 1.35 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                    Circle()
                        .fill(Color.coral)
                        .frame(width: 26, height: 26)
                    Text("YOU")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
                .position(x: cx, y: cy)
            }
        }
        .onAppear {
            pulse = true
            sweepAngle = 360
        }
    }
}
