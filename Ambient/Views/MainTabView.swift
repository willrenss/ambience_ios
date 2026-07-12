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
            // depth > 0 means we pushed into a sub-screen (e.g. RoomView);
            // hide the tab bar so it doesn't overlay chat. Works on both tabs.
            // Hide tab bar when inside chat (bookmarks tab), any pushed screen, or
            // EventMapView's in-place search/radar overlays (full immersive screens,
            // no longer fullScreenCover presentations that would hide the bar for free).
            let pushed = appState.selectedTab == .bookmarks
                      || bookmarksRouter.depth > 0
                      || mapsRouter.depth > 0
                      || appState.isSearchPresented
                      || appState.isRadarPresented
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

    private let teal = Color(hex: 0x1E7082)

    var body: some View {
        HStack(spacing: 0) {
            tabButton(tab: .maps,    icon: "map.fill",    label: "Maps")
            tabButton(tab: .profile, icon: "person.fill", label: "Profile")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 16, y: 4)
    }

    private func tabButton(tab: AppTab, icon: String, label: String) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? teal : Color(.systemGray2))

                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? teal : Color(.systemGray2))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
