import SwiftUI

// MARK: - WalkthroughView

struct WalkthroughView: View {
    let onDone: () -> Void
    @State private var currentPage = 0
    private let total = 3

    var body: some View {
        ZStack {
            pageContent(for: currentPage)
                .id(currentPage)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.38), value: currentPage)
    }

    @ViewBuilder
    private func pageContent(for index: Int) -> some View {
        switch index {
        case 0:
            IntroSlide(
                page: 0, total: total,
                onSkip: onDone,
                onNext: { currentPage = 1 }
            )
        case 1:
            PhotoSlide(
                imageName: "Onboarding2",
                accentWord: "Explore",
                titleRest: " Social\nEvent",
                bodyText: "Browse our live map to see trending events, gatherings, and festivals happening right around you, curated directly from social media. Find where the action is and head over.",
                page: 1, total: total,
                onSkip: onDone,
                onNext: { currentPage = 2 }
            )
        default:
            PhotoSlide(
                imageName: "Onboarding3",
                accentWord: "Unlock",
                titleRest: " Your\nSocial Radar",
                bodyText: "Once you arrive at an event, your Social Radar activates automatically. Scan the room, see who's nearby, and send a real-time ping to connect instantly.",
                page: 2, total: total,
                onSkip: onDone,
                onNext: onDone
            )
        }
    }
}

// MARK: - Intro Slide (orange)

private struct IntroSlide: View {
    let page: Int
    let total: Int
    let onSkip: () -> Void
    let onNext: () -> Void

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // ── Orange hero block ────────────────────────────────────────
                ZStack(alignment: .bottomLeading) {
                    Image("Onboarding1")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height * 0.60)
                        .clipped()

                    VStack(alignment: .leading, spacing: 0) {
                        // Clear area under status bar / Dynamic Island
                        Color.clear.frame(height: geo.safeAreaInsets.top + 16)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("Your\nJourney\nStarts")
                                .font(.system(size: 72, weight: .heavy))
                                .foregroundStyle(.white)
                            Text("Now!")
                                .font(.system(size: 72, weight: .heavy))
                                .foregroundStyle(Color.scale(.brand, 600))
                        }
                        .padding(.horizontal, 28)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: geo.size.height * 0.60)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 28,
                        bottomTrailingRadius: 28,
                        topTrailingRadius: 0
                    )
                )
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 28,
                        bottomTrailingRadius: 28,
                        topTrailingRadius: 0
                    )
                    .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)

                // ── White section ────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    Text("Select your\nInterest")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.top, 22)

                    Text("Select your favorite interests and add your unique hobbies. This helps us customize your map and ensure you discover events and people that truly match your vibe.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                        .padding(.top, 10)

                    Spacer(minLength: 16)

                    WalkthroughNavRow(
                        page: page, total: total, isLast: false,
                        onSkip: onSkip, onNext: onNext
                    )
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 24))
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(.white)
    }

}

// MARK: - Photo Slide

private struct PhotoSlide: View {
    let imageName: String
    let accentWord: String
    let titleRest: String
    let bodyText: String
    let page: Int
    let total: Int
    let onSkip: () -> Void
    let onNext: () -> Void

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // ── Hero image (bottom-rounded, with shadow) ─────────────────
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height * 0.56)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 28,
                            bottomTrailingRadius: 28,
                            topTrailingRadius: 0
                        )
                    )
                    // Shadow behind the image card
                    .shadow(color: .black.opacity(0.20), radius: 14, x: 0, y: 8)

                // ── Text content ─────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    titleLabel.padding(.top, 20)
                    Text(bodyText)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 12)

                WalkthroughNavRow(
                    page: page, total: total,
                    isLast: page == total - 1,
                    onSkip: onSkip, onNext: onNext
                )
                .padding(.horizontal, 24)
                .padding(.bottom, max(geo.safeAreaInsets.bottom, 24))
            }
            .background(.white)
        }
        .ignoresSafeArea(edges: .top)
        .background(.white)
    }

    private var titleLabel: some View {
        Text("\(Text(accentWord).foregroundStyle(Color.coral))\(Text(titleRest).foregroundStyle(Color.primary))")
            .font(.system(size: 32, weight: .bold))
    }
}

// MARK: - Nav Row

private struct WalkthroughNavRow: View {
    let page: Int
    let total: Int
    let isLast: Bool
    let onSkip: () -> Void
    let onNext: () -> Void

    private let teal       = Color(hex: 0x1E7082)
    private let tealShadow = Color(hex: 0x0F4F5E)

    var body: some View {
        HStack(spacing: 0) {
            // Skip — white + stroke + same 3D shadow as Next
            Button(action: onSkip) {
                Text("Skip")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .background {
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        // Dark shadow shape
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.black)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .offset(x: 4, y: 6)
                        // White surface + stroke
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.white)
                            .frame(width: geo.size.width, height: geo.size.height)
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.black.opacity(0.65), lineWidth: 1.5)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
            .padding(.bottom, 7)
            .padding(.trailing, 5)

            Spacer()

            // Dots — gray rounded container with soft shadow
            HStack(spacing: 8) {
                ForEach(0..<total, id: \.self) { i in
                    Circle()
                        .fill(i == page ? Color.black : Color.black.opacity(0.22))
                        .frame(
                            width:  i == page ? 10 : 7,
                            height: i == page ? 10 : 7
                        )
                        .animation(.spring(duration: 0.3), value: page)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
            )
            .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)

            Spacer()

            // Next — teal + thick 3D shadow via separate background shape
            Button(action: onNext) {
                Text(isLast ? "Start" : "Next")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .background {
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        // Dark shadow shape, offset bottom-right
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.black)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .offset(x: 4, y: 6)
                        // Teal main surface
                        RoundedRectangle(cornerRadius: 20)
                            .fill(teal)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
            .padding(.bottom, 7)
            .padding(.trailing, 5)
        }
    }
}
