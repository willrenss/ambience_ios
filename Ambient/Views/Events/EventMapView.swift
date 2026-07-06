import SwiftUI
import MapKit

// MARK: - EventMapView

struct EventMapView: View {
    @State private var viewModel = EventsViewModel()
    @State private var isSearchActive = false
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456),
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
    )
    @Environment(NavigationRouter.self) private var router
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            // Full-screen map
            Map(position: $cameraPosition) {
                UserAnnotation()
                ForEach(viewModel.events) { event in
                    Annotation("", coordinate: CLLocationCoordinate2D(
                        latitude: event.latitude,
                        longitude: event.longitude
                    )) {
                        EventMapPin(event: event)
                            .onTapGesture { router.push(event.id) }
                    }
                }
            }
            .mapStyle(.standard)
            .mapControls { }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Full-width search bar at top ──────────────────────────
                Button { isSearchActive = true } label: {
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
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.chip))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)

                Spacer()

                // ── Bottom-right: map control buttons ─────────────────────
                HStack {
                    Spacer()
                    VStack(spacing: Spacing.sm) {
                        MapControlButton(icon: "binoculars.fill")
                        MapControlButton(icon: "location.north.fill")
                    }
                }
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
        }
        .navigationDestination(for: UUID.self) { id in
            EventDetailView(eventID: id)
        }
        // Search opens as a full-screen cover (slides up over everything)
        .fullScreenCover(isPresented: $isSearchActive) {
            EventSearchCover(viewModel: viewModel, onDismiss: {
                isSearchActive = false
            })
        }
        // When check-in succeeds, activeEvent is set → close the search cover
        .onChange(of: appState.activeEvent) { _, event in
            if event != nil { isSearchActive = false }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

// MARK: - Map control button

private struct MapControlButton: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.primary)
            .frame(width: 40, height: 40)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Map Pin

private struct EventMapPin: View {
    let event: EventDTO

    private var icon: String {
        switch event.category {
        case "Concerts":     return "music.mic"
        case "Exhibitions":  return "paintbrush.fill"
        case "Festivals":    return "sparkles"
        case "Communities":  return "person.3.fill"
        default:             return "mappin.fill"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.coral)
                    .frame(width: 36, height: 36)
                    .shadow(color: Color.coral.opacity(0.4), radius: 5, y: 3)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundStyle(Color.coral)
                .offset(y: -3)
        }
    }
}

// MARK: - EventSearchCover
// Full-screen cover that slides up when the user taps the search bar.
// Has its own NavigationStack so event detail can be pushed from within it.

struct EventSearchCover: View {
    @Bindable var viewModel: EventsViewModel
    let onDismiss: () -> Void
    @FocusState private var searchFocused: Bool

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
            .navigationDestination(for: UUID.self) { id in
                EventDetailView(eventID: id)
            }
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
                    NavigationLink(value: event.id) {
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
                    .foregroundStyle(Color.terracotta)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        ForEach(viewModel.pickedForYou) { event in
                            NavigationLink(value: event.id) {
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
                .foregroundStyle(Color.terracotta)

            categoryChips

            VStack(spacing: Spacing.md) {
                ForEach(viewModel.trending) { event in
                    NavigationLink(value: event.id) {
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
                        .foregroundStyle(viewModel.selectedCategory == nil ? .white : Color.terracotta)
                        .frame(width: 36, height: 36)
                        .background(
                            viewModel.selectedCategory == nil ? Color.coral : Color.white.opacity(0.7),
                            in: Circle()
                        )
                }
                ForEach(EventsViewModel.categories, id: \.self) { cat in
                    Button { viewModel.selectedCategory = cat } label: {
                        Text(cat)
                            .font(.labelLarge)
                            .foregroundStyle(viewModel.selectedCategory == cat ? .white : Color.terracotta)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                viewModel.selectedCategory == cat ? Color.coral : Color.white.opacity(0.7),
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
                    .font(.titleSmall).foregroundStyle(Color.terracotta).lineLimit(1)
                Text(event.locationName ?? "")
                    .font(.labelSmall).foregroundStyle(.secondary)
                if let start = event.startAt {
                    Label(start.searchFormatted, systemImage: "calendar")
                        .font(.labelSmall).foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
            SearchPriceBadge(event: event)
        }
        .padding(Spacing.md)
        .background(.white, in: RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Color.terracotta.opacity(0.07), radius: 6, y: 2)
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
            .background(Color.coral, in: Capsule())
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
