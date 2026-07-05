import SwiftUI

@Observable
@MainActor
final class MatchesViewModel {
    var rooms: [RoomDTO] = []
    var isLoading = false
    var errorMessage: String? = nil

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            rooms = try await MatchService.shared.fetchMatches()
        } catch {
            errorMessage = "Failed to load matches."
        }
    }
}

struct MatchesView: View {
    @State private var viewModel = MatchesViewModel()
    @Environment(NavigationRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                ForEach(viewModel.rooms) { room in
                    Button {
                        router.push(room.id)
                    } label: {
                        MatchRow(room: room)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.lg)
        }
        .background(Color.peach.opacity(0.2))
        .navigationTitle("Matches")
        .navigationDestination(for: UUID.self) { roomID in
            RoomView(roomID: roomID)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.rooms.isEmpty {
                ContentUnavailableView("No Matches Yet", systemImage: "heart.slash",
                    description: Text("Ping people on the radar. When they ping you back, a chat opens here."))
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

private struct MatchRow: View {
    let room: RoomDTO
    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill(Color.apricot).frame(width: 48, height: 48)
                Text(String(room.peerNickname.prefix(1)).uppercased())
                    .font(.titleMedium)
                    .foregroundStyle(Color.terracotta)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(room.peerNickname), \(room.peerAge)")
                    .font(.titleMedium)
                    .foregroundStyle(Color.terracotta)
                if let eventName = room.eventName {
                    Text(eventName).font(.labelSmall).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.labelSmall).foregroundStyle(.tertiary)
        }
        .padding(Spacing.md)
        .background(Color.peach, in: RoundedRectangle(cornerRadius: Radius.card))
    }
}
