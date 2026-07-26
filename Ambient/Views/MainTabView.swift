import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var mapsRouter      = NavigationRouter()
    @State private var bookmarksRouter = NavigationRouter()
    @State private var profileRouter   = NavigationRouter()

    var body: some View {
        @Bindable var appState = appState

        Group {
            switch appState.selectedTab {
            case .maps:
                NavigationStack(path: $mapsRouter.path) {
                    EventMapView()
                }
                .environment(mapsRouter)

            case .bookmarks:
                NavigationStack(path: $bookmarksRouter.path) {
                    MatchesView()
                }
                .environment(bookmarksRouter)

            case .profile:
                NavigationStack(path: $profileRouter.path) {
                    ProfileView()
                }
                .environment(profileRouter)
            }
        }
        .safeAreaInset(edge: .bottom) {
            let pushed = appState.selectedTab == .bookmarks
                      || bookmarksRouter.depth > 0
                      || mapsRouter.depth > 0
                      || appState.isSearchPresented
                      || appState.isRadarPresented
                      || appState.isRadarFlowActive
            if !pushed {
                FloatingTabBar(selectedTab: $appState.selectedTab)
                    .padding(.bottom, 8)
            }
        }
        .onChange(of: appState.activeEvent == nil) { _, _ in
            mapsRouter.popToRoot()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushNotificationOpenRoom)) { note in
            guard let roomID = note.object as? UUID else { return }
            appState.selectedTab = .bookmarks
            bookmarksRouter.push(roomID)
        }
        .task {
            // Trigger NISession creation as soon as the main screen is visible.
            // This makes "Nearby Interactions" appear in iOS Settings and pre-warms
            // the token so it's ready when the user opens a chat room.
            NearbyInteractionService.shared.requestPermissionIfNeeded()
        }
    }
}

// MARK: - Floating Tab Bar

private struct FloatingTabBar: View {
    @Binding var selectedTab: AppTab

    private let selectedColor   = Color(hex: 0x336F7A)
    private let unselectedColor = Color(hex: 0x1A1A1A)
    private let pillColor       = Color(hex: 0xEDEDED)
    private let barBackground   = Color(hex: 0xF7F7F7)
    private let barBorder       = Color(hex: 0xDDDDDD)

    // Fixed, equal-width slots — the sliding pill just offsets between two known
    // positions instead of matchedGeometryEffect-ing an inserted/removed view,
    // which occasionally snapped instead of sliding. Tap target == pill exactly.
    private let tabWidth: CGFloat = 118
    private let tabHeight: CGFloat = 52

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(pillColor)
                .frame(width: tabWidth, height: tabHeight)
                .offset(x: selectedTab == .maps ? 0 : tabWidth)

            HStack(spacing: 0) {
                tabButton(tab: .maps,    icon: "map",    label: "Maps")
                tabButton(tab: .profile, icon: "person", label: "Profile")
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedTab)
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .glassEffect(.regular.tint(barBackground.opacity(0.7)), in: Capsule())
        .overlay(Capsule().stroke(barBorder, lineWidth: 1))
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.8), .clear], startPoint: .top, endPoint: .center),
                    lineWidth: 1
                )
        )
        .shadow(color: barBorder.opacity(0.8), radius: 14, y: 6)
    }

    private func tabButton(tab: AppTab, icon: String, label: String) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? selectedColor : unselectedColor)

                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? selectedColor : unselectedColor)
            }
            .frame(width: tabWidth, height: tabHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
