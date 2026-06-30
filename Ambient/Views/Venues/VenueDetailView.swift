import SwiftUI

@Observable
@MainActor
private final class VenueDetailViewModel {
    var venue: VenueDTO? = nil
    var rooms: [RoomDTO] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var showCreateRoom: Bool = false

    func load(id: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            venue = try await VenueService.shared.fetchVenue(id: id)
            // Rooms are fetched via a dedicated endpoint; here we stub with empty
            // until the backend exposes GET /venues/:id/rooms.
            rooms = []
        } catch {
            errorMessage = "Failed to load venue."
        }
    }
}

struct VenueDetailView: View {
    let venueID: UUID
    @State private var viewModel = VenueDetailViewModel()
    @Environment(NavigationRouter.self) private var router

    var body: some View {
        List {
            if let venue = viewModel.venue {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(venue.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Active Rooms") {
                    if viewModel.rooms.isEmpty {
                        Text("No active rooms")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(viewModel.rooms) { room in
                            Button {
                                router.push(room.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Room")
                                            .font(.headline)
                                        Label("\(room.memberCount) members", systemImage: "person.2")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.venue?.name ?? "Venue")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: UUID.self) { roomID in
            RoomView(roomID: roomID)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showCreateRoom = true
                } label: {
                    Label("Create Room", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.showCreateRoom) {
            if let venue = viewModel.venue {
                CreateRoomView(venue: venue) { newRoom in
                    viewModel.rooms.append(newRoom)
                    viewModel.showCreateRoom = false
                    router.push(newRoom.id)
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task(id: venueID) {
            await viewModel.load(id: venueID)
        }
    }
}
