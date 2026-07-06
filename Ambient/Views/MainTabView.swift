import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    @State private var mapsRouter      = NavigationRouter()
    @State private var bookmarksRouter = NavigationRouter()
    @State private var profileRouter   = NavigationRouter()

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            Tab(AppTab.maps.rawValue, systemImage: AppTab.maps.systemImage, value: AppTab.maps) {
                NavigationStack(path: $mapsRouter.path) {
                    if appState.activeEvent != nil {
                        HomeView()
                    } else {
                        EventMapView()
                    }
                }
                .environment(mapsRouter)
            }

            Tab(AppTab.bookmarks.rawValue, systemImage: AppTab.bookmarks.systemImage, value: AppTab.bookmarks) {
                NavigationStack(path: $bookmarksRouter.path) {
                    MatchesView()
                }
                .environment(bookmarksRouter)
            }

            Tab(AppTab.profile.rawValue, systemImage: AppTab.profile.systemImage, value: AppTab.profile) {
                NavigationStack(path: $profileRouter.path) {
                    ProfileView()
                }
                .environment(profileRouter)
            }
        }
        .onChange(of: appState.activeEvent == nil) { _, _ in
            mapsRouter.popToRoot()
        }
    }
}
