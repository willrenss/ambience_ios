import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home

    // Each tab owns its own router so navigation stacks are independent
    @State private var homeRouter    = NavigationRouter()
    @State private var eventsRouter  = NavigationRouter()
    @State private var matchesRouter = NavigationRouter()
    @State private var profileRouter = NavigationRouter()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.home.rawValue, systemImage: AppTab.home.systemImage, value: AppTab.home) {
                NavigationStack(path: $homeRouter.path) {
                    HomeView()
                }
                .environment(homeRouter)
            }

            Tab(AppTab.events.rawValue, systemImage: AppTab.events.systemImage, value: AppTab.events) {
                NavigationStack(path: $eventsRouter.path) {
                    EventsView()
                }
                .environment(eventsRouter)
            }

            Tab(AppTab.matches.rawValue, systemImage: AppTab.matches.systemImage, value: AppTab.matches) {
                NavigationStack(path: $matchesRouter.path) {
                    MatchesView()
                }
                .environment(matchesRouter)
            }

            Tab(AppTab.profile.rawValue, systemImage: AppTab.profile.systemImage, value: AppTab.profile) {
                NavigationStack(path: $profileRouter.path) {
                    ProfileView()
                }
                .environment(profileRouter)
            }
        }
    }
}
