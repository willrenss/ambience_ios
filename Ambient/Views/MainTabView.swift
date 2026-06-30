import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home

    // Each tab owns its own router so navigation stacks are independent
    @State private var homeRouter     = NavigationRouter()
    @State private var venuesRouter   = NavigationRouter()
    @State private var activityRouter = NavigationRouter()
    @State private var profileRouter  = NavigationRouter()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.home.rawValue, systemImage: AppTab.home.systemImage, value: AppTab.home) {
                NavigationStack(path: $homeRouter.path) {
                    HomeView()
                }
                .environment(homeRouter)
            }

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
