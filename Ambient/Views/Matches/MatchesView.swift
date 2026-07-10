import SwiftUI

@Observable
@MainActor
final class MatchesViewModel {
    var rooms: [RoomDTO] = []
    var isLoading = false
    var errorMessage: String? = nil

    func load(appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let fetched = try await MatchService.shared.fetchMatches()
            rooms = fetched
            appState.recomputeUnread(from: fetched, ownUserID: appState.currentUser?.id)
        } catch {
            errorMessage = "Failed to load matches."
        }
    }

    // Silent background refresh while the list is on screen — no spinner, no error
    // surfaced, so a transient poll failure doesn't interrupt the user. Without this,
    // the preview/highlight only updated when the list was closed and reopened.
    // Unread is derived from the fetched list + AppState's durable seen-watermark, so
    // this needs no in-memory baseline (which is what made detection fragile before).
    func refreshQuietly(appState: AppState, ownUserID: UUID?) async {
        guard let updated = try? await MatchService.shared.fetchMatches() else { return }
        rooms = updated
        appState.recomputeUnread(from: updated, ownUserID: ownUserID)
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
                            MatchRow(room: room, isUnseen: appState.isUnread(room, ownUserID: appState.currentUser?.id))
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
        .task {
            await viewModel.load(appState: appState)
            // Poll while the list is visible so previews/highlights update live —
            // .task auto-cancels this loop when the view disappears.
            let ownUserID = appState.currentUser?.id
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await viewModel.refreshQuietly(appState: appState, ownUserID: ownUserID)
            }
        }
        .refreshable { await viewModel.load(appState: appState) }
    }
}

// MARK: - Row

private struct MatchRow: View {
    let room: RoomDTO
    let isUnseen: Bool

    private let avatarSize: CGFloat = 52

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: avatarSize, height: avatarSize)
                Text(String(room.peerNickname.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                if isUnseen {
                    Circle()
                        .fill(Color.coral)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
            .frame(width: avatarSize, height: avatarSize)

            // Name + preview
            VStack(alignment: .leading, spacing: 3) {
                Text("\(room.peerNickname), \(room.peerAge)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(room.lastMessageText ?? room.eventName ?? "Tap to start chatting")
                    .font(.system(size: 14, weight: isUnseen ? .semibold : .regular))
                    .foregroundStyle(isUnseen ? Color.terracotta : .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 12)
        .background(isUnseen ? Color.peach.opacity(0.3) : .clear)
        .contentShape(Rectangle())
    }
}
