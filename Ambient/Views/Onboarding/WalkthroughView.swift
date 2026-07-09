import SwiftUI

struct WalkthroughView: View {
    let onDone: () -> Void
    @State private var currentPage = 0

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
            OnboardingInterestView(
                onNext: { currentPage = 1 }
            )
        case 1:
            OnboardingExploreSocialEventView(
                onSkip: onDone,
                onNext: { currentPage = 2 }
            )
        default:
            OnboardingRadarView(
                onSkip: onDone,
                onNext: onDone
            )
        }
    }
}
