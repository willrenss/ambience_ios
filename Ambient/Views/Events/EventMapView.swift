import SwiftUI
import MapKit

// MARK: - EventMapView

private struct MapSheetEvent: Identifiable { let id: UUID }

struct EventMapView: View {
    @State private var viewModel = EventsViewModel()
    @State private var sheetEvent: MapSheetEvent?
    @State private var previewEvent: EventDTO?   // event currently shown in overlay
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456),
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
    )
    @Environment(AppState.self) private var appState

    private let teal  = Color(hex: 0x1E7082)
    private let brand = Color(hex: 0xD63200)

    var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var appState = appState
        let isPreviewShowing = (previewEvent ?? appState.activeEvent) != nil

        ZStack {
            // Full-screen map
            Map(position: $cameraPosition) {
                UserAnnotation()
                ForEach(viewModel.trending) { event in
                    Annotation("", coordinate: CLLocationCoordinate2D(
                        latitude: event.latitude,
                        longitude: event.longitude
                    )) {
                        EventMapPin(
                            event: event,
                            isSelected: previewEvent?.id == event.id || appState.activeEvent?.id == event.id,
                            isActive: appState.activeEvent?.id == event.id
                        )
                        .onTapGesture {
                            if appState.activeEvent?.id == event.id {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    appState.isRadarPresented = true
                                }
                            } else {
                                previewEvent = event
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard)
            .mapControls { }
            .ignoresSafeArea()
            .onTapGesture { previewEvent = nil }
            
            VStack(spacing: 0) {
                // ── Search bar ─────────────────────────────────────────────
                Button {
                    withAnimation(.easeInOut(duration: 0.32)) {
                        appState.isSearchPresented = true
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        Text("Search on Map")
                            .font(.bodyMedium)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(.white, in: RoundedRectangle(cornerRadius: 60, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                }
                .buttonStyle(.plain)
                .opacity(appState.isSearchPresented ? 0 : 1)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)

                // ── Category chips ──────────────────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(EventsViewModel.categories, id: \.self) { cat in
                            Button {
                                viewModel.selectedCategory = viewModel.selectedCategory == cat ? nil : cat
                            } label: {
                                Text(cat)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(viewModel.selectedCategory == cat ? .white : .primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        viewModel.selectedCategory == cat ? teal : Color.white,
                                        in: Capsule()
                                    )
                                    .shadow(color: .black.opacity(0.07), radius: 4, y: 1)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }
                .background(Color.white.opacity(0.001))
                .padding(.top, Spacing.sm)
                
                Spacer()

                // ── Location button ────────────────────────────────────────
                // 100 clears the floating tab bar; add card height + gap when a preview/checked-in card is showing.
                HStack {
                    Spacer()
                    Button {
                        Task {
                            // Live GPS fix, not a hardcoded coordinate — silent no-op if unavailable.
                            guard let location = await LocationService.shared.awaitLocation() else { return }
                            withAnimation(.easeInOut(duration: 0.6)) {
                                cameraPosition = .region(
                                    MKCoordinateRegion(
                                        center: location.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
                                    )
                                )
                            }
                        }
                    } label: {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(teal, in: Circle())
                            .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
                    }
                }
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, isPreviewShowing ? 260 : 100)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPreviewShowing)
            }
            
            // Overlay card — shows preview (pin tap) or checked-in state
            if let displayed = previewEvent ?? appState.activeEvent {
                let isCheckedIn = appState.activeEvent?.id == displayed.id
                VStack {
                    Spacer()
                    overlayCard(event: displayed, isCheckedIn: isCheckedIn)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: displayed.id)
            }

            // In-place fade, not fullScreenCover's slide-up — pure opacity avoids the edge gap scale+fade left.
            if appState.isSearchPresented {
                NavigationStack {
                    EventsView(viewModel: viewModel, onDismiss: {
                        withAnimation(.easeInOut(duration: 0.28)) {
                            appState.isSearchPresented = false
                        }
                    })
                }
                .environment(appState)
                .transition(.opacity)
            }

            // Radar — same in-place ease/fade treatment as search, instead of
            // fullScreenCover's fixed slide-up-from-bottom transition.
            if appState.isRadarPresented {
                RadarHost(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appState.isRadarPresented = false
                    }
                })
                .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $sheetEvent, onDismiss: {
            // EventDetailView fully dismissed — now safe to open radar if user checked in.
            if appState.activeEvent != nil {
                appState.shouldAutoConnectRadar = true
                withAnimation(.easeInOut(duration: 0.3)) {
                    appState.isRadarPresented = true
                }
            }
        }) { e in
            EventDetailView(eventID: e.id)
        }
        .onChange(of: appState.activeEvent) { _, event in
            if event == nil {
                withAnimation(.easeInOut(duration: 0.3)) {
                    appState.isRadarPresented = false
                }
                previewEvent = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventBookmarkChanged)) { note in
            guard let updated = note.object as? EventDTO else { return }
            if previewEvent?.id == updated.id { previewEvent = updated }
            if appState.activeEvent?.id == updated.id { appState.activeEvent = updated }
            viewModel.applyBookmarkUpdate(updated)
        }
        .task { await viewModel.load() }
    }
    
    // MARK: - Overlay card (unified: preview + checked-in)
    
    private func overlayCard(event: EventDTO, isCheckedIn: Bool) -> some View {
        // Card — tap opens radar (if checked in) or detail (if preview)
        Button {
            if isCheckedIn {
                withAnimation(.easeInOut(duration: 0.3)) {
                    appState.isRadarPresented = true
                }
            } else {
                sheetEvent = MapSheetEvent(id: event.id)
            }
        } label: {
            HStack(spacing: Spacing.md) {
                // Thumbnail
                Color.clear
                    .frame(width: 100, height: 106)
                    .overlay {
                        if let urlStr = event.imageURL, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color(.systemGray5)
                            }
                        } else {
                            Color(.systemGray5)
                        }
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    if let cat = event.category {
                        Text(cat)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(brand)
                    }
                    Text(event.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let loc = event.locationName {
                        Text(loc)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    HStack(spacing: Spacing.sm) {
                        if isCheckedIn {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                Text("Checked In")
                                    .font(.labelSmall)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 4)
                            .background(brand, in: Capsule())
                        } else {
                            SearchPriceBadge(event: event)
                        }
                        Spacer(minLength: 0)
                        // Mini avatar stack — checked-in shows who's online right
                        // now (live radar); preview shows who's bookmarked it.
                        HStack(spacing: -10) {
                            let previews = isCheckedIn ? event.onlineAttendees : event.bookmarkAttendees
                            let total = isCheckedIn ? event.onlineCount : event.bookmarkCount
                            ForEach(Array(previews.prefix(3).enumerated()), id: \.offset) { _, preview in
                                avatarStackEntry(preview)
                            }
                            let shown = min(previews.count, 3)
                            if total > shown {
                                Text("+\(total - shown)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(brand, in: Circle())
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .background(.white, in: RoundedRectangle(cornerRadius: Radius.card))
            .shadow(color: .black.opacity(0.10), radius: 20, y: 6)
            // Heart button pinned to top-left corner of the card
            .overlay(alignment: .topLeading) {
                if !isCheckedIn {
                    Button { toggleBookmark(event) } label: {
                        Image(systemName: event.isBookmarked ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.coral)
                            .frame(width: 44, height: 44)
                            .background(.white, in: Circle())
                            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                    }
                    .offset(x: -8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func avatarStackEntry(_ preview: EventAttendeePreviewDTO) -> some View {
        Group {
            if let urlStr = preview.photoURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    avatarStackPlaceholder(preview.initial)
                }
            } else {
                avatarStackPlaceholder(preview.initial)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 2))
    }

    private func avatarStackPlaceholder(_ initial: String) -> some View {
        Circle()
            .fill(Color(.systemGray3))
            .overlay(Text(initial).font(.system(size: 9, weight: .bold)).foregroundStyle(.white))
    }

    // Optimistic flip on previewEvent, reverted on failure; also syncs viewModel.events and
    // broadcasts .eventBookmarkChanged so EventDetailView/EventsView stay in sync.
    private func toggleBookmark(_ event: EventDTO) {
        guard var updated = previewEvent, updated.id == event.id else { return }
        let wasBookmarked = updated.isBookmarked
        updated.isBookmarked.toggle()
        updated.bookmarkCount += updated.isBookmarked ? 1 : -1
        previewEvent = updated
        viewModel.applyBookmarkUpdate(updated)
        NotificationCenter.default.post(name: .eventBookmarkChanged, object: updated)

        Task {
            do {
                if updated.isBookmarked {
                    try await EventService.shared.bookmark(eventID: event.id)
                } else {
                    try await EventService.shared.unbookmark(eventID: event.id)
                }
            } catch {
                guard previewEvent?.id == event.id else { return }
                var reverted = updated
                reverted.isBookmarked = wasBookmarked
                reverted.bookmarkCount += wasBookmarked ? 1 : -1
                previewEvent = reverted
                viewModel.applyBookmarkUpdate(reverted)
                NotificationCenter.default.post(name: .eventBookmarkChanged, object: reverted)
            }
        }
    }
}

// Carries the updated EventDTO; EventMapView stays mounted underneath both the search
// overlay and EventDetailView's sheet, so it's the sync hub for all bookmark toggles.
extension Notification.Name {
    static let eventBookmarkChanged = Notification.Name("com.nowi.eventBookmarkChanged")
}

// MARK: - Radar Host

// Isolated NavigationRouter/NavigationStack for radar, separate from mapsRouter —
// prevents a push here from leaking a stray path value into the map's own stack.
private struct RadarHost: View {
    @State private var radarRouter = NavigationRouter()
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack(path: $radarRouter.path) {
            HomeView(onDismiss: onDismiss)
        }
        .environment(radarRouter)
    }
}

// MARK: - Map Pin

private struct EventMapPin: View {
    let event: EventDTO
    var isSelected: Bool = false
    var isActive: Bool = false

    private let teal = Color(hex: 0x1E7082)

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Outer pulse ring when selected or active
                if isSelected {
                    Circle()
                        .stroke(Color.coral.opacity(0.3), lineWidth: 4)
                        .frame(width: 62, height: 62)
                }

                // Gradient fill — merah saat di-tap/selected, teal saat normal
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [Color.coral, Color(red: 0.72, green: 0.14, blue: 0.14)]
                                : [teal, Color(hex: 0x134F5C)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                    .shadow(color: (isSelected ? Color.coral : teal).opacity(0.4), radius: 8, y: 4)

                Image(systemName: isActive ? "checkmark" : categoryIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(event.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var categoryIcon: String {
        switch event.category?.lowercased() {
        case "concerts":    return "music.note"
        case "exhibitions": return "building.columns"
        case "festivals":   return "sparkles"
        case "communities": return "person.2.fill"
        default:            return "calendar"
        }
    }
}

// MARK: - EventSearchCover

struct EventSearchCover: View {
    @Bindable var viewModel: EventsViewModel
    let onDismiss: () -> Void
    @FocusState private var searchFocused: Bool
    @State private var sheetEventID: MapSheetEvent?
    private let teal = Color(hex: 0x1E7082)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    if viewModel.isSearching {
                        searchResultsSection
                    } else {
                        pickedForYouSection
                        trendingSection
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxxl)
            }
            .scrollIndicators(.hidden)
            .background(Color.peach.opacity(0.2).ignoresSafeArea())
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search events"
            )
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .fullScreenCover(item: $sheetEventID) { e in
            EventDetailView(eventID: e.id)
        }
        .onAppear { searchFocused = true }
        .onDisappear { viewModel.searchText = "" }
    }
    
    // MARK: - Search results
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if viewModel.searchResults.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ForEach(viewModel.searchResults) { event in
                    Button { sheetEventID = MapSheetEvent(id: event.id) } label: {
                        SearchEventRow(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Picked for you
    
    @ViewBuilder
    private var pickedForYouSection: some View {
        if !viewModel.pickedForYou.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Events Picked for You")
                    .font(.headlineSmall)
                    .foregroundStyle(teal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        ForEach(viewModel.pickedForYou) { event in
                            Button { sheetEventID = MapSheetEvent(id: event.id) } label: {
                                SearchPickedCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, -Spacing.lg)
                .padding(.leading, Spacing.lg)
            }
        }
    }
    
    // MARK: - Trending
    
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Trending Events")
                .font(.headlineSmall)
                .foregroundStyle(teal)
            
            categoryChips
            
            VStack(spacing: Spacing.md) {
                ForEach(viewModel.trending) { event in
                    Button { sheetEventID = MapSheetEvent(id: event.id) } label: {
                        SearchEventRow(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                Button { viewModel.selectedCategory = nil } label: {
                    Image(systemName: viewModel.selectedCategory == nil ? "heart.fill" : "heart")
                        .foregroundStyle(viewModel.selectedCategory == nil ? .white : teal)
                        .frame(width: 36, height: 36)
                        .background(
                            viewModel.selectedCategory == nil ? teal : Color.white.opacity(0.7),
                            in: Circle()
                        )
                }
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(teal)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.7), in: Circle())
                ForEach(EventsViewModel.categories, id: \.self) { cat in
                    Button { viewModel.selectedCategory = cat } label: {
                        Text(cat)
                            .font(.labelLarge)
                            .foregroundStyle(viewModel.selectedCategory == cat ? .white : teal)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                viewModel.selectedCategory == cat ? teal : Color.white.opacity(0.7),
                                in: Capsule()
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Cards

private struct SearchPickedCard: View {
    let event: EventDTO
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SearchEventImage(url: event.imageURL)
                .frame(width: 220, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            
            LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .bottom, endPoint: .center)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            
            SearchPriceBadge(event: event)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Spacing.sm)
            
            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                Text(event.name)
                    .font(.titleSmall).foregroundStyle(.white).lineLimit(1)
                Text(event.locationName ?? "")
                    .font(.labelSmall).foregroundStyle(.white.opacity(0.8))
                if let start = event.startAt {
                    Text(start.searchFormatted)
                        .font(.labelSmall).foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(Spacing.md)
        }
        .frame(width: 220, height: 150)
    }
}

private struct SearchEventRow: View {
    let event: EventDTO
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            SearchEventImage(url: event.imageURL)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: Radius.chip))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.titleSmall).foregroundStyle(Color(hex: 0x1E7082)).lineLimit(1)
                Text(event.locationName ?? "")
                    .font(.labelSmall).foregroundStyle(Color(hex: 0x1E7082).opacity(0.6))
                if let start = event.startAt {
                    Label(start.searchFormatted, systemImage: "calendar")
                        .font(.labelSmall).foregroundStyle(Color(hex: 0x1E7082).opacity(0.6))
                }
            }
            
            Spacer(minLength: 0)
            SearchPriceBadge(event: event)
        }
        .padding(Spacing.md)
        .background(.white, in: RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Color(hex: 0x1E7082).opacity(0.07), radius: 6, y: 2)
    }
}

// MARK: - Helpers

private struct SearchPriceBadge: View {
    let event: EventDTO
    
    var body: some View {
        Text(label)
            .font(.labelSmall).foregroundStyle(.white)
            .lineLimit(1).minimumScaleFactor(0.8)
            .padding(.horizontal, Spacing.sm).padding(.vertical, 4)
            .background(Color(hex: 0xD63200), in: Capsule())
    }
    
    private var label: String {
        guard let price = event.hargaTiket, price > 0 else { return "Free Entry" }
        return "From Rp\(Int(price).searchFormatted)"
    }
}

private struct SearchEventImage: View {
    let url: String?
    
    var body: some View {
        if let url, let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: placeholder
                }
            }
        } else {
            placeholder
        }
    }
    
    private var placeholder: some View {
        LinearGradient(colors: [Color.apricot, Color.coral],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private extension Date {
    var searchFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: self)
    }
}

private extension Int {
    var searchFormatted: String {
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

#Preview("Event Map") {
    EventMapView()
        .environment(NavigationRouter())
        .environment(AppState())
}
