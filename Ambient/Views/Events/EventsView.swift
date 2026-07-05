import SwiftUI

@Observable
@MainActor
final class EventsViewModel {
    var events: [EventDTO] = []
    var searchText: String = ""
    var selectedCategory: String? = nil   // nil = "All" (heart chip)
    var isLoading: Bool = false
    var errorMessage: String? = nil

    static let categories = ["Concerts", "Exhibitions", "Festivals", "Communities"]

    // Soonest-starting few, shown in the "Events Picked for You" carousel.
    // No real personalization/curation backend yet — this is just the same
    // sorted-by-start-date list the trending section uses, sliced down.
    var pickedForYou: [EventDTO] {
        Array(events.prefix(3))
    }

    var trending: [EventDTO] {
        guard let selectedCategory else { return events }
        return events.filter { $0.category == selectedCategory }
    }

    var searchResults: [EventDTO] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return events.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || ($0.locationName?.localizedCaseInsensitiveContains(q) ?? false)
                || ($0.category?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            events = try await EventService.shared.fetchEvents()
        } catch {
            errorMessage = "Failed to load events."
        }
    }
}

struct EventsView: View {
    @State private var viewModel = EventsViewModel()
    @Environment(NavigationRouter.self) private var router
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var router = router

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                searchBar

                if viewModel.isSearching {
                    searchResultsSection
                } else {
                    pickedForYouSection
                    trendingSection
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
        .background(Color.peach.opacity(0.2))
        .navigationDestination(for: UUID.self) { eventID in
            EventDetailView(eventID: eventID)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.events.isEmpty {
                ContentUnavailableView("No Events", systemImage: "calendar.badge.exclamationmark",
                                       description: Text("No events available right now."))
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search events", text: $viewModel.searchText)
                    .font(.bodyMedium)
                    .focused($searchFocused)
                if !viewModel.isSearching {
                    Image(systemName: "mic.fill").foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.white.opacity(0.6), in: Capsule())

            if viewModel.isSearching || searchFocused {
                Button {
                    viewModel.searchText = ""
                    searchFocused = false
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.terracotta)
                        .frame(width: 36, height: 36)
                        .background(.white, in: Circle())
                }
            }
        }
    }

    // MARK: - Search results (flat list)

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(viewModel.searchResults) { event in
                Button { router.push(event.id) } label: {
                    TrendingEventRow(event: event)
                }
                .buttonStyle(.plain)
            }
            if viewModel.searchResults.isEmpty {
                Text("No events match \"\(viewModel.searchText)\".")
                    .font(.bodyMedium)
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.xl)
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
                            Button { router.push(event.id) } label: {
                                PickedForYouCard(event: event)
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
                    Button { router.push(event.id) } label: {
                        TrendingEventRow(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                Button {
                    viewModel.selectedCategory = nil
                } label: {
                    Image(systemName: viewModel.selectedCategory == nil ? "heart.fill" : "heart")
                        .foregroundStyle(viewModel.selectedCategory == nil ? .white : Color.terracotta)
                        .frame(width: 36, height: 36)
                        .background(viewModel.selectedCategory == nil ? Color.coral : Color.white.opacity(0.7),
                                    in: Circle())
                }

                ForEach(EventsViewModel.categories, id: \.self) { category in
                    Button {
                        viewModel.selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.labelLarge)
                            .foregroundStyle(viewModel.selectedCategory == category ? .white : Color.terracotta)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(viewModel.selectedCategory == category ? Color.coral : Color.white.opacity(0.7),
                                        in: Capsule())
                    }
                }
            }
        }
    }
}

// MARK: - Cards

private struct PickedForYouCard: View {
    let event: EventDTO

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            EventImage(url: event.imageURL)
                .frame(width: 260, height: 170)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card))

            LinearGradient(
                colors: [.black.opacity(0.75), .black.opacity(0.15), .clear],
                startPoint: .bottom, endPoint: .center
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))

            // Anchored independently to top-leading — without this it inherits
            // the ZStack's own .bottomLeading alignment and collapses into the
            // same corner as the title/date block below, overlapping it.
            PriceBadge(event: event, size: .small)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Spacing.md)

            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                Text(event.name)
                    .font(.titleMedium)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(event.locationName ?? "")
                    .font(.labelSmall)
                    .foregroundStyle(.white.opacity(0.85))

                HStack {
                    if let start = event.startAt {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 5))
                            Text(start.formatted(dotStyle: true))
                                .font(.labelSmall)
                                .foregroundStyle(.white)
                        }
                    }
                    Spacer()
                    AttendeeStack(event: event, dark: true, size: .small)
                }
            }
            .padding(Spacing.md)
        }
        .frame(width: 260, height: 170)
    }
}

private struct TrendingEventRow: View {
    let event: EventDTO

    var body: some View {
        HStack(spacing: Spacing.md) {
            EventImage(url: event.imageURL)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: Radius.chip))

            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.titleSmall)
                    .foregroundStyle(Color.terracotta)
                    .lineLimit(1)
                Text(event.locationName ?? "")
                    .font(.labelSmall)
                    .foregroundStyle(.secondary)
                HStack {
                    if let start = event.startAt {
                        Label(start.formatted(dotStyle: true), systemImage: "calendar")
                            .font(.labelSmall)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    AttendeeStack(event: event, dark: false)
                }
            }

            Spacer(minLength: 0)
            PriceBadge(event: event)
        }
        .padding(Spacing.md)
        .background(.white, in: RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: Color.terracotta.opacity(0.08), radius: 6, y: 2)
    }
}

private enum BadgeSize { case small, large }

private struct PriceBadge: View {
    let event: EventDTO
    var size: BadgeSize = .small

    var body: some View {
        Text(label)
            .font(size == .large ? .labelMedium : .labelSmall)
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(width: size == .large ? 100 : 88)
            .padding(.horizontal, size == .large ? Spacing.md : Spacing.sm)
            .padding(.vertical, size == .large ? Spacing.sm : 4)
            .background(Color.coral, in: Capsule())
    }

    // Always the same "From RpX" shape (never abbreviated to "425k") so every
    // badge in a list renders at the same size regardless of price magnitude.
    private var label: String {
        guard let price = event.hargaTiket, price > 0 else { return "Free Entry" }
        return "From Rp\(Int(price).formattedThousands)"
    }
}

// Real initials of a few joined attendees, per the "no fully anonymous"
// product decision — deliberately just initials (never a full nickname or
// a photo) even here, to keep the exposure minimal.
private struct AttendeeStack: View {
    let event: EventDTO
    let dark: Bool
    var size: BadgeSize = .small

    private var diameter: CGFloat { size == .large ? 40 : 22 }
    private var overlap: CGFloat { size == .large ? -12 : -8 }
    private var borderWidth: CGFloat { size == .large ? 2.5 : 1.5 }
    private var fontSize: CGFloat { size == .large ? 15 : 9 }

    var body: some View {
        if event.attendeeCount > 0 {
            HStack(spacing: overlap) {
                ForEach(Array(event.attendeeInitials.prefix(3).enumerated()), id: \.offset) { index, initial in
                    Circle()
                        .fill(Color.apricot)
                        .frame(width: diameter, height: diameter)
                        .overlay(Text(initial).font(.system(size: fontSize, weight: .bold)).foregroundStyle(Color.terracotta))
                        .overlay(Circle().stroke(dark ? .white : Color.peach.opacity(0.2), lineWidth: borderWidth))
                }
                let overflow = event.attendeeCount - min(event.attendeeInitials.count, 3)
                if overflow > 0 {
                    Circle()
                        .fill(Color.coral)
                        .frame(width: diameter, height: diameter)
                        .overlay(Text("+\(overflow)").font(.system(size: fontSize - 1, weight: .bold)).foregroundStyle(.white))
                        .overlay(Circle().stroke(dark ? .white : Color.peach.opacity(0.2), lineWidth: borderWidth))
                }
            }
        }
    }
}

private struct EventImage: View {
    let url: String?

    var body: some View {
        if let url, let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        LinearGradient(colors: [Color.apricot, Color.coral], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private extension Date {
    func formatted(dotStyle: Bool) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: self)
    }
}

private extension Int {
    // Manual comma grouping so the "From Rp50,000" style matches the
    // reference design regardless of the device's region format.
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
