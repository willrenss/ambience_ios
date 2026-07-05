import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home

    // Each tab owns its own router so navigation stacks are independent
<<<<<<< HEAD
    @State private var homeRouter     = NavigationRouter()
    @State private var venuesRouter   = NavigationRouter()
    @State private var activityRouter = NavigationRouter()
    @State private var profileRouter  = NavigationRouter()
=======
    @State private var homeRouter    = NavigationRouter()
    @State private var eventsRouter  = NavigationRouter()
    @State private var matchesRouter = NavigationRouter()
    @State private var profileRouter = NavigationRouter()
>>>>>>> c5f4022 (Iniatial Commit)

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.home.rawValue, systemImage: AppTab.home.systemImage, value: AppTab.home) {
                NavigationStack(path: $homeRouter.path) {
                    HomeView()
                }
                .environment(homeRouter)
            }

<<<<<<< HEAD
            Tab(AppTab.venues.rawValue, systemImage: AppTab.venues.systemImage, value: AppTab.venues) {
                NavigationStack(path: $venuesRouter.path) {
                    VenuesView()
                }
                .environment(venuesRouter)
            }

            Tab(AppTab.activity.rawValue, systemImage: AppTab.activity.systemImage, value: AppTab.activity) {
                NavigationStack(path: $activityRouter.path) {
                    ActivityView()
                }
                .environment(activityRouter)
=======
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
>>>>>>> c5f4022 (Iniatial Commit)
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
