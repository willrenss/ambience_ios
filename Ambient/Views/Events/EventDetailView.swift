import SwiftUI
import CoreLocation

@Observable
@MainActor
final class EventDetailViewModel {
    var event: EventDTO? = nil
    var isLoading = false
    var isJoining = false
    var errorMessage: String? = nil

    var distanceMeters: Double? = nil
    var radarEligible: Bool = false
    var joined = false

    private let radiusMeters: Double = 500

    func load(id: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            event = try await EventService.shared.fetchEvent(id: id)
        } catch {
            errorMessage = "Failed to load event."
        }
    }

    // Attempt to arm radar. Returns the radarToken + event on success so the caller
    // can start EventRadarService and navigate to Home.
    func joinRadar(appState: AppState) async -> Bool {
        guard let event else { return false }
        isJoining = true
        errorMessage = nil
        defer { isJoining = false }

        guard let loc = await LocationService.shared.awaitLocation() else {
            errorMessage = "Couldn't get your location. Enable Location access."
            return false
        }

        do {
            let resp = try await EventService.shared.join(
                eventID: event.id,
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude)
            distanceMeters = resp.distanceMeters
            radarEligible = resp.radarEligible
            guard resp.radarEligible else {
                HapticManager.shared.play(.error)
                return false
            }

            // BLE/radar itself only arms once the user explicitly taps "Tap to
            // Connect" on Home — this just marks the event as joined so Home
            // knows which event/token to connect to.
            appState.activeEvent = event
            appState.activeEventID = event.id
            joined = true
            return true
        } catch {
            errorMessage = "Couldn't join. Try again."
            return false
        }
    }
}

struct EventDetailView: View {
    let eventID: UUID
    @State private var viewModel = EventDetailViewModel()
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                if let event = viewModel.event {
                    Text(event.name)
                        .font(.displaySmall)
                        .foregroundStyle(Color.terracotta)

                    if let start = event.startAt {
                        infoRow("clock", start.formatted(date: .complete, time: .shortened))
                    }
                    if let price = event.hargaTiket {
                        infoRow("ticket", price == 0 ? "Free" : String(format: "Rp %.0f", price))
                    }
                    if let desc = event.deskripsi, !desc.isEmpty {
                        Text(desc).font(.bodyMedium).foregroundStyle(.secondary)
                    }

                    if let link = event.linkRegistrasi, let url = URL(string: link) {
                        Link(destination: url) {
                            Label("Registration", systemImage: "link")
                                .font(.labelLarge)
                                .foregroundStyle(Color.infoBlue)
                        }
                    }

                    radiusSection
                }
            }
            .padding(Spacing.lg)
        }
        .background(Color.peach.opacity(0.2))
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if viewModel.isLoading { ProgressView() } }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
        .task(id: eventID) { await viewModel.load(id: eventID) }
    }

    @ViewBuilder
    private var radiusSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let dist = viewModel.distanceMeters {
                if viewModel.radarEligible {
                    Label(String(format: "You're %.0fm away — within range!", dist),
                          systemImage: "checkmark.circle.fill")
                        .font(.labelLarge)
                        .foregroundStyle(Color.successGreen)
                } else {
                    Label(String(format: "You're %.0fm away. Get within 500m to activate radar.", dist),
                          systemImage: "location.slash")
                        .font(.labelLarge)
                        .foregroundStyle(Color.warningAmber)
                }
            }

            if viewModel.isJoining {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Button {
                    Task {
                        if await viewModel.joinRadar(appState: appState) {
                            dismiss()   // pop back; RootView routes to radar Home once activeEventID set
                        }
                    }
                } label: {
                    Text(viewModel.radarEligible ? "Enter Radar" : "Check Distance & Join Radar")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.top, Spacing.sm)
    }

    private func infoRow(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.bodyMedium)
            .foregroundStyle(.secondary)
    }
}

// Stable 8-byte hex radar token derived from the user's UUID. Deterministic so the
// same user always advertises the same token across radar sessions.
enum RadarToken {
    static func derive(from userID: UUID) -> String {
        let b = userID.uuid
        let bytes = [b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7]
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
