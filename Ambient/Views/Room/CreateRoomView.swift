import SwiftUI

@Observable
@MainActor
private final class CreateRoomViewModel {
    var proximityToken: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil

    func createRoom(venueID: UUID) async -> RoomDTO? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let token = proximityToken.trimmingCharacters(in: .whitespaces).isEmpty
            ? UUID().uuidString   // stub token for MVP
            : proximityToken

        do {
            let room = try await RoomService.shared.createRoom(venueID: venueID, proximityToken: token)
            HapticManager.shared.playSuccessHaptic()
            return room
        } catch {
            errorMessage = "Failed to create room. Please try again."
            return nil
        }
    }
}

struct CreateRoomView: View {
    let venue: VenueDTO
    let onCreated: (RoomDTO) -> Void

    @State private var viewModel = CreateRoomViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Venue", value: venue.name)
                    LabeledContent("Address", value: venue.address)
                }

                Section {
                    TextField("Proximity token (optional)", text: $viewModel.proximityToken)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Proximity Token")
                } footer: {
                    Text("Leave blank for auto-generated token during MVP. Required for UWB pairing in production.")
                        .font(.footnote)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }

                Section {
                    Button {
                        Task {
                            if let room = await viewModel.createRoom(venueID: venue.id) {
                                onCreated(room)
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Create Room")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .navigationTitle("New Room")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
