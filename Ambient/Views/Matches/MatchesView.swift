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
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var router = router

        VStack(spacing: 0) {
            // Custom header with back-to-radar button
            HStack {
                Button {
                    appState.selectedTab = .maps
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.terracotta)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                Text("Chats")
                    .font(.system(size: 17, weight: .semibold))

                Spacer()

                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 8)

            Divider().opacity(0.2)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.rooms) { room in
                        Button {
                            router.push(room.id)
                        } label: {
                            MatchRow(room: room)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, Spacing.sm)
            }
        }
        .background(Color.peach.opacity(0.15).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: UUID.self) { roomID in
            RoomView(roomID: roomID)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.rooms.isEmpty {
                ContentUnavailableView(
                    "No Chats Yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Ping people on the radar. When they ping you back, a chat opens here.")
                )
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

// MARK: - Row

private struct MatchRow: View {
    let room: RoomDTO

    private let avatarSize: CGFloat = 52

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: avatarSize, height: avatarSize)
                Text(String(room.peerNickname.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Name + preview
            VStack(alignment: .leading, spacing: 3) {
                Text("\(room.peerNickname), \(room.peerAge)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(room.eventName ?? "Tap to start chatting")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
