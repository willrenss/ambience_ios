import SwiftUI

@Observable
@MainActor
final class EventsViewModel {
    var events: [EventDTO] = []
    var searchText: String = ""
    var selectedCategory: String? = nil
    // Heart chip for SEARCH/BROWSE view — client-side filter, independent of map.
    var showBookmarkedOnly: Bool = false
    var isLoading: Bool = false
    var errorMessage: String? = nil

    // ── Map bookmark filter ─────────────────────────────────────────────────
    // Same client-side source as showBookmarkedOnly so both views stay in sync.
    var mapBookmarkActive: Bool = false
    var isMapBookmarkLoading: Bool = false

    // Disesuaikan urutannya agar sama persis dengan screenshot
    static let categories = ["Exhibitions", "Festivals", "Communities", "Concerts"]

    var pickedForYou: [EventDTO] {
        Array(events.prefix(3))
    }

    // Used by EventsView/EventSearchCover — client-side bookmark filter.
    var trending: [EventDTO] {
        if showBookmarkedOnly { return events.filter { $0.isBookmarked } }
        guard let selectedCategory else { return events }
        return events.filter { $0.category == selectedCategory }
    }

    // Used ONLY by EventMapView — same client-side source as trending so both stay in sync.
    var mapTrending: [EventDTO] {
        if mapBookmarkActive { return events.filter { $0.isBookmarked } }
        guard let selectedCategory else { return events }
        return events.filter { $0.category == selectedCategory }
    }

    func toggleMapBookmark() {
        mapBookmarkActive.toggle()
        if mapBookmarkActive { selectedCategory = nil }
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

    // Syncs a bookmark toggle from elsewhere (EventMapView/EventDetailView) — see .eventBookmarkChanged.
    func applyBookmarkUpdate(_ updated: EventDTO) {
        guard let idx = events.firstIndex(where: { $0.id == updated.id }) else { return }
        events[idx] = updated
    }
}

struct EventsView: View {
    @Bindable var viewModel: EventsViewModel
    // Override for callers without a real presentation context (e.g. in-place overlay); falls back to dismiss.
    var onDismiss: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool
    private let teal = Color(hex: 0x4FA0B0)

    var body: some View {
        VStack(spacing: 0) {
            // Header selalu menempel di atas (Search Bar + Category Chips)
            pinnedHeader

            // State Loading / Empty dipindahkan ke dalam agar tidak memblokir header
            if viewModel.isLoading && viewModel.events.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.events.isEmpty {
                Spacer()
                ContentUnavailableView("No Events", systemImage: "calendar.badge.exclamationmark",
                                       description: Text("No events available right now."))
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Tampilkan hasil search JIKA sedang mencari atau sedang mengetik
                        if viewModel.isSearching || searchFocused {
                            searchResultsSection
                        } else {
                            pickedForYouSection
                            
                            Text("Trending Events")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 16)
                            
                            trendingListSection
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively) // UX: Tutup keyboard saat user scroll
            }
        }
        .background(Color(white: 0.97).ignoresSafeArea())
        .navigationDestination(for: UUID.self) { eventID in
            EventDetailView(eventID: eventID)
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
    }

    // MARK: - Fixed header (Search bar + Category chips)

    private var pinnedHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            searchBar
                .padding(.horizontal, 16)

            categoryChips
        }
        .padding(.top, Spacing.sm)
        .padding(.bottom, 8)
        .background(Color(white: 0.97).ignoresSafeArea(edges: .top))
        .zIndex(1)
    }

    // MARK: - Search bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Button { onDismiss?() ?? dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 46, height: 46)
                    .background(.white, in: Circle())
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                
                TextField("Search...", text: $viewModel.searchText)
                    .font(.system(size: 16))
                    .focused($searchFocused)
                    .submitLabel(.search)
                
                if viewModel.searchText.isEmpty {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color(.systemGray3))
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(.white, in: Capsule())
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                // Heart Icon — bookmarked-only filter (toggle: tap again to clear it
                // and go back to showing everything).
                Button {
                    viewModel.showBookmarkedOnly.toggle()
                    if viewModel.showBookmarkedOnly { viewModel.selectedCategory = nil }
                } label: {
                    Image(systemName: viewModel.showBookmarkedOnly ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(viewModel.showBookmarkedOnly ? .white : .primary)
                        .frame(width: 38, height: 38)
                        .background(viewModel.showBookmarkedOnly ? teal : .white, in: Circle())
                        .overlay(
                            Circle().stroke(Color(white: 0.9), lineWidth: viewModel.showBookmarkedOnly ? 0 : 1)
                        )
                }

                // Categories — tap again to clear (same toggle behavior as the heart
                // chip, so there's always a way back to "no filter" from either axis).
                ForEach(EventsViewModel.categories, id: \.self) { category in
                    Button {
                        viewModel.selectedCategory = viewModel.selectedCategory == category ? nil : category
                        if viewModel.selectedCategory != nil { viewModel.showBookmarkedOnly = false }
                    } label: {
                        Text(category)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(viewModel.selectedCategory == category ? .white : .primary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(viewModel.selectedCategory == category ? teal : .white, in: Capsule())
                            .overlay(
                                Capsule().stroke(Color(white: 0.9), lineWidth: viewModel.selectedCategory == category ? 0 : 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Search results
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(viewModel.searchResults) { event in
                NavigationLink(value: event.id) {
                    SearchSuggestionRow(event: event) // Gunakan UI khusus search sesuai gambar
                }
                .buttonStyle(.plain)
            }
            if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                Text("No events match \"\(viewModel.searchText)\".")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Picked for you
    
    @ViewBuilder
    private var pickedForYouSection: some View {
        if !viewModel.pickedForYou.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Events Picked for You")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(viewModel.pickedForYou) { event in
                            NavigationLink(value: event.id) {
                                PickedForYouCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Trending List

    private var trendingListSection: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.trending) { event in
                NavigationLink(value: event.id) {
                    TrendingEventRow(event: event)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Cards (UI Components)

// 1. Desain Card Baru untuk hasil pencarian
private struct SearchSuggestionRow: View {
    let event: EventDTO
    
    private let badgeColor = Color(red: 0.88, green: 0.28, blue: 0.1) // Terracotta

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .stroke(badgeColor, lineWidth: 1.5)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: categoryIcon)
                        .font(.system(size: 18))
                        .foregroundStyle(badgeColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(event.locationName ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }
    
    private var categoryIcon: String {
        switch event.category?.lowercased() {
        case "concerts":    return "music.note"
        case "exhibitions": return "party.popper"
        case "festivals":   return "sparkles"
        case "communities": return "person.2"
        default:            return "calendar"
        }
    }
}


// 2. Picked for You Card
private struct PickedForYouCard: View {
    let event: EventDTO

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            EventImage(url: event.imageURL)
                .frame(width: 280, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            LinearGradient(
                colors: [.black.opacity(0.8), .black.opacity(0.2), .clear],
                startPoint: .bottom, endPoint: .center
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text(event.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(event.locationName ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    if let start = event.startAt {
                        Text(start.formatted(dotStyle: true))
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .padding(.top, 4)
            }
            .padding(16)
        }
        .frame(width: 280, height: 180)
    }
}

// 3. Trending Event Row
private struct TrendingEventRow: View {
    let event: EventDTO

    var body: some View {
        HStack(spacing: 16) {
            EventImage(url: event.imageURL)
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text(event.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                Text(event.locationName ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    if let start = event.startAt {
                        Text(start.formatted(dotStyle: true))
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
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
        Color(white: 0.9)
    }
}

// MARK: - Extensions

private extension Date {
    func formatted(dotStyle: Bool) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: self)
    }
}

#Preview("Events View") {
    NavigationStack {
        EventsView(viewModel: EventsViewModel())
    }
}
