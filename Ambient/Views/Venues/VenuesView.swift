import SwiftUI

struct VenuesView: View {
    @State private var viewModel = VenuesViewModel()
    @Environment(NavigationRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        List(viewModel.filteredVenues) { venue in
            Button {
                router.push(venue.id)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(venue.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(venue.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search venues")
        .navigationTitle("Venues")
        .navigationDestination(for: UUID.self) { venueID in
            VenueDetailView(venueID: venueID)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.venues.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Venues",
                    systemImage: "mappin.slash",
                    description: Text("No venues found nearby.")
                )
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            await viewModel.loadVenues()
        }
    }
}
