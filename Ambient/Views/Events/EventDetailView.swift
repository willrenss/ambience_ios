//import SwiftUI
//import CoreLocation
//
//// MARK: - ViewModel
//
//@Observable
//@MainActor
//final class EventDetailViewModel {
//    var event: EventDTO? = nil
//    var isLoading = false
//    var isJoining = false
//    var errorMessage: String? = nil
//
//    var distanceMeters: Double? = nil
//    var radarEligible: Bool = false
//    var joined = false
//
//    func load(id: UUID) async {
//        isLoading = true
//        errorMessage = nil
//        defer { isLoading = false }
//        do {
//            event = try await EventService.shared.fetchEvent(id: id)
//        } catch {
//            errorMessage = "Failed to load event."
//        }
//    }
//
//    func joinRadar(appState: AppState) async -> Bool {
//        guard let event else { return false }
//        isJoining = true
//        errorMessage = nil
//        defer { isJoining = false }
//
//        guard let loc = await LocationService.shared.awaitLocation() else {
//            errorMessage = "Couldn't get your location. Enable Location access."
//            return false
//        }
//
//        do {
//            let resp = try await EventService.shared.join(
//                eventID: event.id,
//                latitude: loc.coordinate.latitude,
//                longitude: loc.coordinate.longitude)
//            distanceMeters = resp.distanceMeters
//            radarEligible = resp.radarEligible
//            guard resp.radarEligible else {
//                HapticManager.shared.play(.error)
//                return false
//            }
//            appState.activeEvent = event
//            appState.activeEventID = event.id
//            joined = true
//            return true
//        } catch {
//            errorMessage = "Couldn't join. Try again."
//            return false
//        }
//    }
//}
//
//// MARK: - View
//
//struct EventDetailView: View {
//    let eventID: UUID
//    @State private var viewModel = EventDetailViewModel()
//    @State private var isFavorited = false
//    @State private var showStatusIntent = false
//    @State private var statusIntentConfirmed = false
//    @Environment(AppState.self) private var appState
//    @Environment(\.dismiss) private var dismiss
//
//    private let teal       = Color(hex: 0x1E7082)
//    private let tealShadow = Color(hex: 0x0F4F5E)
//
//    private enum EventStatus { case upcoming, active, ended }
//
//    private var eventStatus: EventStatus {
//        guard let event = viewModel.event else { return .upcoming }
//        let now = Date.now
//        if let end = event.endAt, end < now { return .ended }
//        if let start = event.startAt, start > now { return .upcoming }
//        return .active
//    }
//
//    var body: some View {
//        ZStack(alignment: .top) {
//            Image("eventBackgroundDetail")
//                .resizable()
//                .scaledToFill()
//                .ignoresSafeArea()
//
//            ScrollView {
//                VStack(spacing: 0) {
//                    if let event = viewModel.event {
//                        heroArea(event: event)
//
//                        VStack(alignment: .leading, spacing: Spacing.xl) {
//                            dateAndPriceCard(event: event)
//                            if let desc = event.deskripsi, !desc.isEmpty {
//                                detailSection(desc: desc)
//                            }
//                            if let link = event.linkRegistrasi, !link.isEmpty {
//                                whereToBuyRow(link: link)
//                            }
//                        }
//                        .padding(.horizontal, Spacing.lg)
//                        .padding(.top, Spacing.lg)
//                        .padding(.bottom, 120)
//                    } else if !viewModel.isLoading {
//                        ProgressView()
//                            .frame(maxWidth: .infinity)
//                            .padding(.top, 200)
//                    }
//                }
//            }
//            .scrollIndicators(.hidden)
//
//            // Back + Heart overlay — plain HStack (ZStack .top handles alignment;
//            // no outer VStack+Spacer so the hit area doesn't shadow the ScrollView)
//            HStack {
//                Button { dismiss() } label: {
//                    Image(systemName: "chevron.left")
//                        .font(.system(size: 18, weight: .semibold))
//                        .foregroundStyle(.black)
//                        .frame(width: 44, height: 44)
//                        .contentShape(Rectangle())
//                        .background(.white, in: Circle())
//                        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
//                }
//                .buttonStyle(.plain)
//                Spacer()
//                Button { isFavorited.toggle() } label: {
//                    Image(systemName: isFavorited ? "heart.fill" : "heart")
//                        .font(.system(size: 18, weight: .semibold))
//                        .foregroundStyle(isFavorited ? Color.coral : .primary)
//                        .frame(width: 44, height: 44)
//                        .contentShape(Rectangle())
//                        .background(.white, in: Circle())
//                        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
//                }
//                .buttonStyle(.plain)
//            }
//            .padding(.horizontal, Spacing.lg)
//            .padding(.top, Spacing.sm)
//
//            // Fixed bottom button
//            if viewModel.event != nil {
//                VStack {
//                    Spacer()
//                    bottomButton
//                        .padding(.horizontal, Spacing.lg)
//                        .padding(.bottom, 36)
//                }
//                .ignoresSafeArea(edges: .bottom)
//            }
//        }
//        .fullScreenCover(isPresented: $showStatusIntent, onDismiss: {
//            if statusIntentConfirmed { dismiss() }
//        }) {
//            StatusIntentView { status in
//                try? await APIClient.shared.patch("/me", body: StatusPatchBody(status: status))
//                statusIntentConfirmed = true
//            }
//        }
//        .navigationBarHidden(true)
//        .navigationBarBackButtonHidden(true)
//        .toolbar(.hidden, for: .navigationBar)
//        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
//            Button("OK") { viewModel.errorMessage = nil }
//        } message: { Text(viewModel.errorMessage ?? "") }
//        .task(id: eventID) { await viewModel.load(id: eventID) }
//    }
//
//    // MARK: - Hero
//
//    private func heroArea(event: EventDTO) -> some View {
//        ZStack(alignment: .bottom) {
//            // Hero image — fixed container via overlay so image load never shifts layout
//            Color.clear
//                .frame(maxWidth: .infinity)
//                .frame(height: 340)
//                .overlay {
//                    if let urlString = event.imageURL, let url = URL(string: urlString) {
//                        AsyncImage(url: url) { img in
//                            img.resizable().scaledToFill()
//                        } placeholder: {
//                            heroBgFallback
//                        }
//                    } else {
//                        heroBgFallback
//                    }
//                }
//                .clipped()
//                .clipShape(
//                    UnevenRoundedRectangle(
//                        bottomLeadingRadius: 28,
//                        bottomTrailingRadius: 28
//                    )
//                )
//
//            VStack(alignment: .leading, spacing: 8) {
//                // Avatar stack — only when there are attendees
//                if event.attendeeCount > 0 {
//                    attendeeAvatarRow(event: event)
//                        .padding(.horizontal, Spacing.xl)
//                }
//
//                // Floating name/location card
//                VStack(alignment: .leading, spacing: 4) {
//                    Text(event.name)
//                        .font(.headlineSmall)
//                        .foregroundStyle(.primary)
//                        .lineLimit(2)
//                    if let loc = event.locationName {
//                        Text(loc)
//                            .font(.labelMedium)
//                            .foregroundStyle(teal)
//                    }
//                }
//                .padding(.horizontal, Spacing.lg)
//                .padding(.vertical, Spacing.md)
//                .frame(maxWidth: .infinity, alignment: .leading)
//                .background(
//                    RoundedRectangle(cornerRadius: Radius.card)
//                        .fill(.white)
//                        .shadow(color: .black.opacity(0.1), radius: 16, y: 4)
//                )
//                .padding(.horizontal, Spacing.xl)
//            }
//            .offset(y: 36)
//        }
//        .padding(.bottom, 36)
//    }
//
//    private func attendeeAvatarRow(event: EventDTO) -> some View {
//        HStack(spacing: 0) {
//            HStack(spacing: -12) {
//                ForEach(Array(event.attendeeInitials.prefix(5).enumerated()), id: \.offset) { _, initials in
//                    Circle()
//                        .fill(Color(.systemGray4))
//                        .frame(width: 36, height: 36)
//                        .overlay(
//                            Text(initials)
//                                .font(.system(size: 12, weight: .semibold))
//                                .foregroundStyle(.primary)
//                        )
//                        .overlay(Circle().stroke(.white, lineWidth: 2))
//                }
//                let shown = min(event.attendeeInitials.count, 5)
//                if event.attendeeCount > shown {
//                    let extra = event.attendeeCount - shown
//                    Text("+\(extra)")
//                        .font(.system(size: 13, weight: .bold))
//                        .foregroundStyle(.white)
//                        .frame(width: 36, height: 36)
//                        .background(teal, in: Circle())
//                        .overlay(Circle().stroke(.white, lineWidth: 2))
//                }
//            }
//            Spacer()
//        }
//    }
//
//    private var heroBgFallback: some View {
//        LinearGradient(
//            colors: [Color.apricot, Color.coral],
//            startPoint: .topLeading,
//            endPoint: .bottomTrailing
//        )
//    }
//
//    // MARK: - Date & Price card
//
//    private func dateAndPriceCard(event: EventDTO) -> some View {
//        HStack(spacing: 0) {
//            VStack(alignment: .leading, spacing: 2) {
//                Text(event.startAt.map { EventDetailView.longDate($0) } ?? "TBA")
//                    .font(.titleSmall)
//                    .foregroundStyle(.primary)
//                Text("Date")
//                    .font(.labelSmall)
//                    .foregroundStyle(.secondary)
//            }
//            .frame(maxWidth: .infinity, alignment: .leading)
//
//            Divider()
//                .frame(height: 36)
//                .padding(.horizontal, Spacing.lg)
//
//            VStack(alignment: .leading, spacing: 2) {
//                Text(event.hargaTiket.map { $0 == 0 ? "Free" : "From Rp\(Int($0).formattedThousands)" } ?? "TBA")
//                    .font(.titleSmall)
//                    .foregroundStyle(.primary)
//                Text("Price")
//                    .font(.labelSmall)
//                    .foregroundStyle(.secondary)
//            }
//            .frame(maxWidth: .infinity, alignment: .leading)
//        }
//        .padding(.horizontal, Spacing.lg)
//        .padding(.vertical, Spacing.md)
//        .background(
//            RoundedRectangle(cornerRadius: Radius.chip)
//                .stroke(Color.peach, lineWidth: 1.5)
//        )
//    }
//
//    // MARK: - Detail
//
//    private func detailSection(desc: String) -> some View {
//        VStack(alignment: .leading, spacing: Spacing.sm) {
//            Text("Detail")
//                .font(.headlineSmall)
//                .foregroundStyle(.primary)
//            Text(desc)
//                .font(.bodyMedium)
//                .foregroundStyle(.secondary)
//                .lineSpacing(4)
//        }
//        .padding(.horizontal, Spacing.lg)
//        .padding(.vertical, Spacing.md)
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .background(
//            RoundedRectangle(cornerRadius: Radius.chip)
//                .stroke(Color.peach, lineWidth: 1.5)
//        )
//    }
//
//    // MARK: - Where to Buy
//
//    private func whereToBuyRow(link: String) -> some View {
//        Group {
//            if let url = URL(string: link) {
//                Link(destination: url) { whereToBuyContent }
//            } else {
//                whereToBuyContent
//            }
//        }
//    }
//
//    private var whereToBuyContent: some View {
//        HStack {
//            Text("Where to Buy")
//                .font(.labelLarge)
//                .foregroundStyle(.primary)
//            Spacer()
//            HStack(spacing: Spacing.sm) {
//                ZStack {
//                    RoundedRectangle(cornerRadius: 8)
//                        .fill(Color(hex: 0x0069D9))
//                        .frame(width: 32, height: 32)
//                    Image(systemName: "ticket.fill")
//                        .font(.system(size: 14, weight: .semibold))
//                        .foregroundStyle(.white)
//                }
//                Image(systemName: "chevron.right")
//                    .font(.system(size: 13, weight: .semibold))
//                    .foregroundStyle(.secondary)
//            }
//        }
//        .padding(.horizontal, Spacing.lg)
//        .padding(.vertical, Spacing.md)
//        .background(
//            RoundedRectangle(cornerRadius: Radius.chip)
//                .stroke(Color.peach, lineWidth: 1.5)
//        )
//    }
//
//    // MARK: - Bottom button
//
//    @ViewBuilder
//    private var bottomButton: some View {
//        switch eventStatus {
//        case .upcoming:
//            disabledButton(title: "Awaiting Event Start")
//
//        case .ended:
//            disabledButton(title: "Event Has Ended")
//
//        case .active:
//            if viewModel.isJoining {
//                ProgressView().frame(maxWidth: .infinity).frame(height: 54)
//            } else {
//                VStack(spacing: Spacing.sm) {
//                    if let dist = viewModel.distanceMeters, !viewModel.radarEligible {
//                        Text(String(format: "You're %.0fm away — get within 500m", dist))
//                            .font(.labelSmall)
//                            .foregroundStyle(Color.warningAmber)
//                            .frame(maxWidth: .infinity, alignment: .center)
//                    }
//                    Button {
//                        Task {
//                            let ok = await viewModel.joinRadar(appState: appState)
//                            if ok { showStatusIntent = true }
//                        }
//                    } label: {
//                        Text("I'm in the Area")
//                            .font(.system(size: 17, weight: .bold))
//                            .frame(maxWidth: .infinity)
//                            .frame(height: 54)
//                            .foregroundStyle(.black)
//                    }
//                    .buttonStyle(.plain)
//                    .background {
//                        GeometryReader { g in
//                            ZStack(alignment: .topLeading) {
//                                RoundedRectangle(cornerRadius: 27)
//                                    .fill(.black)
//                                    .frame(width: g.size.width, height: g.size.height)
//                                    .offset(x: 4, y: 6)
//                                RoundedRectangle(cornerRadius: 27)
//                                    .fill(teal)
//                                    .frame(width: g.size.width, height: g.size.height)
//                            }
//                        }
//                    }
//                    .padding(.bottom, 7)
//                    .padding(.trailing, 5)
//                }
//            }
//        }
//    }
//
//    private func disabledButton(title: String) -> some View {
//        Text(title)
//            .font(.system(size: 17, weight: .semibold))
//            .frame(maxWidth: .infinity)
//            .frame(height: 54)
//            .foregroundStyle(Color.primary.opacity(0.35))
//            .background {
//                GeometryReader { g in
//                    ZStack(alignment: .topLeading) {
//                        RoundedRectangle(cornerRadius: 27)
//                            .fill(.black.opacity(0.55))
//                            .frame(width: g.size.width, height: g.size.height)
//                            .offset(x: 4, y: 6)
//                        RoundedRectangle(cornerRadius: 27)
//                            .fill(Color(.systemGray5))
//                            .frame(width: g.size.width, height: g.size.height)
//                    }
//                }
//            }
//            .padding(.bottom, 7)
//            .padding(.trailing, 5)
//    }
//
//    // MARK: - Helpers
//
//    private static func longDate(_ date: Date) -> String {
//        let f = DateFormatter()
//        f.dateFormat = "d MMMM yyyy"
//        f.locale = Locale(identifier: "en_US")
//        return f.string(from: date)
//    }
//}
//
//// MARK: - Radar token
//
//enum RadarToken {
//    static func derive(from userID: UUID) -> String {
//        let b = userID.uuid
//        let bytes = [b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7]
//        return bytes.map { String(format: "%02x", $0) }.joined()
//    }
//}
//
//// MARK: - Shared formatter (used by EventsView too)
//
//private extension Int {
//    var formattedThousands: String {
//        var chars = Array(String(self))
//        var groups: [String] = []
//        while chars.count > 3 {
//            groups.insert(String(chars.suffix(3)), at: 0)
//            chars.removeLast(3)
//        }
//        groups.insert(String(chars), at: 0)
//        return groups.joined(separator: ",")
//    }
//}
//
//#Preview("Event Detail") {
//    EventDetailView(eventID: UUID())
//        .environment(AppState())
//}

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

    // Optimistic toggle, matching EventMapView's overlayCard pattern — flips
    // immediately, reverts if the request fails.
    func toggleBookmark() async {
        guard var updated = event else { return }
        let wasBookmarked = updated.isBookmarked
        updated.isBookmarked.toggle()
        updated.bookmarkCount += updated.isBookmarked ? 1 : -1
        event = updated
        // EventMapView (which stays mounted underneath this sheet) listens for this
        // and syncs its own previewEvent/viewModel.events — otherwise pressing back
        // would land on the stale bookmark state from before this toggle.
        NotificationCenter.default.post(name: .eventBookmarkChanged, object: updated)

        do {
            if updated.isBookmarked {
                try await EventService.shared.bookmark(eventID: updated.id)
            } else {
                try await EventService.shared.unbookmark(eventID: updated.id)
            }
        } catch {
            guard event?.id == updated.id else { return }
            var reverted = updated
            reverted.isBookmarked = wasBookmarked
            reverted.bookmarkCount += wasBookmarked ? 1 : -1
            event = reverted
            NotificationCenter.default.post(name: .eventBookmarkChanged, object: reverted)
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
    @State private var showStatusIntent = false
    @State private var statusIntentConfirmed = false
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private let tealColor = Color(hex: 0x2A6B77) // Warna disesuaikan dengan tombol area mockup

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
            // Background Base Faded Gray
            Color(.systemGray6)
                .ignoresSafeArea()

            if let event = viewModel.event {
                // Banner Atas (Hero Image)
                GeometryReader { geo in
                    if let urlString = event.imageURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { img in
                            img.resizable()
                               .scaledToFill()
                               .frame(width: geo.size.width, height: 380)
                               .clipped()
                        } placeholder: {
                            heroBgFallback.frame(width: geo.size.width, height: 380)
                        }
                    } else {
                        heroBgFallback.frame(width: geo.size.width, height: 380)
                    }
                }
                .ignoresSafeArea(edges: .top)

                // Scrollable Content Layer
                ScrollView {
                    VStack(spacing: 0) {
                        // Spacer transparan agar konten card mulai di area tengah bawah gambar hero
                        Color.clear
                            .frame(height: 260)

                        // Utama Konten berbentuk Ticket Card terpadu
                        VStack(alignment: .leading, spacing: 0) {
                            
                            // === BAGIAN ATAS TIKET ===
                            VStack(alignment: .leading, spacing: 12) {
                                Text(event.category ?? "Events")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(hex: 0x1E7082))
                                
                                Text(event.name)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(.black)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text(event.locationName ?? "TBA")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                
                                // Grid Waktu dan Tanggal
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.startAt.map { formatDate($0) } ?? "TBA")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(.black)
                                        Text("Date")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.startAt.map { formatTime($0) } ?? "TBA")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(.black)
                                        Text("Time")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.top, 8)
                                
                                // Info Harga
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.hargaTiket.map { $0 == 0 ? "Free" : "From Rp\($0.formattedThousands)" } ?? "TBA")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.black)
                                    Text("Price")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 4)
                            }
                            .padding(.all, 24)
                            
                            // === GARIS PEMBATAS TIKET (DOTTED + SIDE NOTCH) ===
                            TicketDivider()
                                .frame(height: 20)
                            
                            // === BAGIAN BAWAH TIKET ===
                            VStack(alignment: .leading, spacing: 20) {
                                // Deskripsi / Detail
                                if let desc = event.deskripsi, !desc.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Detail")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(.black)
                                        Text(desc)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                            .lineSpacing(4)
                                    }
                                }
                                
                                // Informasi Tambahan (Organizer, Where to Buy, Apple Maps Link)
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Additional Info")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.black)
                                    
                                    if let organizer = event.organizer {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Organizer")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                            Text(organizer)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(.black)
                                        }
                                    }
                                    
                                    // Where to Buy Row
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Where to Buy")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                        
                                        if let linkReg = event.linkRegistrasi, let url = URL(string: linkReg) {
                                            Link(destination: url) {
                                                HStack {
                                                    Image(systemName: "ticket.fill")
                                                        .font(.system(size: 13))
                                                    Text(event.source?.capitalized ?? "Ticket Vendor")
                                                        .font(.system(size: 14, weight: .semibold))
                                                }
                                                .foregroundStyle(Color(hex: 0x0A3641))
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 44)
                                                .background(Color(.systemGray5).opacity(0.6))
                                                .clipShape(Capsule())
                                            }
                                        }
                                    }
                                    
                                    // Apple Maps Link Row (Menggantikan Social Links)
                                    if let linkMaps = event.linkMaps, let urlMaps = URL(string: linkMaps) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Location Link")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                            
                                            Link(destination: urlMaps) {
                                                HStack {
                                                    Image(systemName: "map.fill")
                                                        .font(.system(size: 13))
                                                    Text("Open in Apple Maps")
                                                        .font(.system(size: 14, weight: .semibold))
                                                }
                                                .foregroundStyle(.white)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 44)
                                                .background(Color(hex: 0x1E7082))
                                                .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.all, 24)
                        }
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 140) // Memberikan ruang agar tidak tertutup tombol sticky bottom
                    }
                }
                .scrollIndicators(.hidden)
            } else if !viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Floating Navigation Overlay (Back & Heart Buttons)
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button { Task { await viewModel.toggleBookmark() } } label: {
                    Image(systemName: viewModel.event?.isBookmarked == true ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(viewModel.event?.isBookmarked == true ? .red : .black)
                        .frame(width: 44, height: 44)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Fixed Sticky Bottom Button Layer
            if viewModel.event != nil {
                VStack {
                    Spacer()
                    bottomButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 34)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .fullScreenCover(isPresented: $showStatusIntent, onDismiss: {
            if statusIntentConfirmed { dismiss() }
        }) {
            StatusIntentView { status in
                try? await APIClient.shared.patch("/me", body: StatusPatchBody(status: status))
                statusIntentConfirmed = true
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
        .task(id: eventID) { await viewModel.load(id: eventID) }
    }

    // MARK: - Components Helper
    
    private var heroBgFallback: some View {
        LinearGradient(
            colors: [Color.orange.opacity(0.6), Color.red.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var bottomButton: some View {
        switch eventStatus {
        case .upcoming:
            disabledButton(title: "Awaiting Event Start")
        case .ended:
            disabledButton(title: "Event Has Ended")
        case .active:
            if viewModel.isJoining {
                ProgressView().frame(maxWidth: .infinity).frame(height: 56)
            } else {
                VStack(spacing: 6) {
                    if let dist = viewModel.distanceMeters, !viewModel.radarEligible {
                        Text(String(format: "You're %.0fm away — get within 500m", dist))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                    
                    Button {
                        Task {
                            let ok = await viewModel.joinRadar(appState: appState)
                            if ok { showStatusIntent = true }
                        }
                    } label: {
                        Text("I'm in the Area")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(tealColor)
                            .clipShape(Capsule())
                            .shadow(color: tealColor.opacity(0.4), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func disabledButton(title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(.systemGray4))
            .clipShape(Capsule())
    }

    // MARK: - Date Formatter
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        f.locale = Locale(identifier: "en_US")
        return f.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.locale = Locale(identifier: "en_US")
        return f.string(from: date)
    }
}

// MARK: - Custom Component: Ticket Divider Line
struct TicketDivider: View {
    var body: some View {
        HStack(spacing: 0) {
            // Lekukan kiri kedalam tiket
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: 20, height: 20)
                .offset(x: -10)
            
            // Garis putus-putus tengah
            Line()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundStyle(Color(.systemGray4))
                .frame(height: 1)
            
            // Lekukan kanan kedalam tiket
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: 20, height: 20)
                .offset(x: 10)
        }
    }
    
    struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: rect.height / 2))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height / 2))
            return path
        }
    }
}

// MARK: - Extension Hex Color
extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Ext Double
private extension Double {
    var formattedThousands: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: self)) ?? "\(Int(self))"
    }
}
