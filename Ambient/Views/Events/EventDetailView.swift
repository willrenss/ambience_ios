import SwiftUI
import CoreLocation

// MARK: - ViewModel

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

// MARK: - View

struct EventDetailView: View {
    let eventID: UUID
    @State private var viewModel = EventDetailViewModel()
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private enum EventStatus { case upcoming, active, ended }

    private var eventStatus: EventStatus {
        guard let event = viewModel.event else { return .upcoming }
        let now = Date.now
        if let end = event.endAt, end < now { return .ended }
        if let start = event.startAt, start > now { return .upcoming }
        return .active
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: 0xF5F0EB).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    if let event = viewModel.event {
                        heroArea(event: event)

                        VStack(alignment: .leading, spacing: Spacing.xl) {
                            dateAndPriceCard(event: event)
                            if let desc = event.deskripsi, !desc.isEmpty {
                                detailSection(desc: desc)
                            }
                            if let link = event.linkRegistrasi, !link.isEmpty {
                                whereToBuyRow(link: link)
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.lg)
                        .padding(.bottom, 110)
                    } else if !viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 200)
                    }
                }
            }
            .scrollIndicators(.hidden)

            // Back button overlay on top of hero
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                Spacer()
            }

            // Fixed bottom button
            if viewModel.event != nil {
                VStack {
                    Spacer()
                    bottomButton
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, 36)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
        .task(id: eventID) { await viewModel.load(id: eventID) }
    }

    // MARK: - Hero

    private func heroArea(event: EventDTO) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Hero image
            Group {
                if let urlString = event.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: heroBgFallback
                        }
                    }
                } else {
                    heroBgFallback
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 340)
            .clipped()
            .clipShape(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: 28,
                    bottomTrailingRadius: 28
                )
            )

            // Floating name/location card
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.headlineSmall)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let loc = event.locationName {
                    Text(loc)
                        .font(.labelMedium)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.card)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.1), radius: 16, y: 4)
            )
            .padding(.horizontal, Spacing.xl)
            .offset(y: 36)
        }
        .padding(.bottom, 36)
    }

    private var heroBgFallback: some View {
        LinearGradient(
            colors: [Color.apricot, Color.coral],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Date & Price card

    private func dateAndPriceCard(event: EventDTO) -> some View {
        HStack(spacing: 0) {
            // Date column
            VStack(alignment: .leading, spacing: 2) {
                Text(event.startAt.map { EventDetailView.longDate($0) } ?? "TBA")
                    .font(.titleSmall)
                    .foregroundStyle(.primary)
                Text("Date")
                    .font(.labelSmall)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .frame(height: 36)
                .padding(.horizontal, Spacing.lg)

            // Price column
            VStack(alignment: .leading, spacing: 2) {
                Text(event.hargaTiket.map { $0 == 0 ? "Free" : "From Rp\(Int($0).formattedThousands)" } ?? "TBA")
                    .font(.titleSmall)
                    .foregroundStyle(.primary)
                Text("Price")
                    .font(.labelSmall)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.chip)
                .stroke(Color.peach, lineWidth: 1.5)
        )
    }

    // MARK: - Detail

    private func detailSection(desc: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Detail")
                .font(.headlineSmall)
                .foregroundStyle(.primary)
            Text(desc)
                .font(.bodyMedium)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }

    // MARK: - Where to Buy

    private func whereToBuyRow(link: String) -> some View {
        Group {
            if let url = URL(string: link) {
                Link(destination: url) {
                    whereToBuyContent
                }
            } else {
                whereToBuyContent
            }
        }
    }

    private var whereToBuyContent: some View {
        HStack {
            Text("Where to Buy")
                .font(.labelLarge)
                .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: Spacing.sm) {
                // Tiket.com-style badge
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: 0x0069D9))
                        .frame(width: 32, height: 32)
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.chip)
                .stroke(Color.peach, lineWidth: 1.5)
        )
    }

    // MARK: - Bottom button

    @ViewBuilder
    private var bottomButton: some View {
        switch eventStatus {
        case .upcoming:
            Text("Awaiting Event Start")
                .font(.labelLarge)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(Color.primary.opacity(0.35))
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.chip))

        case .ended:
            Text("Event Has Ended")
                .font(.labelLarge)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(Color.primary.opacity(0.35))
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.chip))

        case .active:
            if viewModel.isJoining {
                ProgressView().frame(maxWidth: .infinity).frame(height: 50)
            } else {
                VStack(spacing: Spacing.sm) {
                    if let dist = viewModel.distanceMeters, !viewModel.radarEligible {
                        Text(String(format: "You're %.0fm away — get within 500m", dist))
                            .font(.labelSmall)
                            .foregroundStyle(Color.warningAmber)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    Button {
                        Task {
                            // Setting activeEvent triggers EventMapView.onChange →
                            // fullScreenCover dismisses automatically, no dismiss() needed.
                            _ = await viewModel.joinRadar(appState: appState)
                        }
                    } label: {
                        Text(viewModel.radarEligible ? "Check In" : "Check Distance")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }

    // MARK: - Helpers

    private static func longDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        f.locale = Locale(identifier: "en_US")
        return f.string(from: date)
    }
}

// MARK: - Radar token

enum RadarToken {
    static func derive(from userID: UUID) -> String {
        let b = userID.uuid
        let bytes = [b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7]
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Shared formatter (used by EventsView too)

private extension Int {
    var formattedThousands: String {
        var chars = Array(String(self))
        var groups: [String] = []
        while chars.count > 3 {
            groups.insert(String(chars.suffix(3)), at: 0)
            chars.removeLast(3)
        }
        groups.insert(String(chars), at: 0)
        return groups.joined(separator: ",")
    }
}
