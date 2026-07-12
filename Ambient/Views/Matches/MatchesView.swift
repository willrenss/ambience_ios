import SwiftUI

@Observable
final class MatchesViewModel {
    var rooms: [RoomDTO] = []
    var isLoading = false
    var errorMessage: String? = nil

    init(rooms: [RoomDTO] = []) {
        self.rooms = rooms
    }

    @MainActor
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

    @MainActor
    func refreshQuietly(appState: AppState, ownUserID: UUID?) async {
        guard let updated = try? await MatchService.shared.fetchMatches() else { return }
        rooms = updated
        appState.recomputeUnread(from: updated, ownUserID: ownUserID)
    }
}

struct MatchesView: View {
    @State private var viewModel: MatchesViewModel
    @Environment(NavigationRouter.self) private var router
    @Environment(AppState.self) private var appState

    init(viewModel: MatchesViewModel = MatchesViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    private let brand = Color(hex: 0xD63200)

    var body: some View {
        @Bindable var router = router

        VStack(spacing: 0) {
            chatHeader
            chatList
        }
        .background(Color.white.ignoresSafeArea(.all, edges: .bottom))
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(brand, for: .navigationBar)
        .navigationDestination(for: UUID.self) { roomID in
            RoomView(roomID: roomID)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.rooms.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 44))
                        .foregroundStyle(brand.opacity(0.4))
                    Text("No Chats Yet")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Ping people on the radar.\nWhen they ping back, a chat opens here.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 160)
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
        .task {
            await viewModel.load(appState: appState)
            let ownUserID = appState.currentUser?.id
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await viewModel.refreshQuietly(appState: appState, ownUserID: ownUserID)
            }
        }
        .refreshable { await viewModel.load(appState: appState) }
    }

    // MARK: - Header

    private var chatHeader: some View {
        ZStack(alignment: .bottom) {
            // Background extends behind status bar
            ZStack {
                brand
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.25, y: h))
                        path.addQuadCurve(
                            to: CGPoint(x: w + 10, y: h * 0.28),
                            control: CGPoint(x: w * 0.75, y: h * 1.05)
                        )
                        path.addLine(to: CGPoint(x: w + 10, y: h * 0.52))
                        path.addQuadCurve(
                            to: CGPoint(x: w * 0.25, y: h),
                            control: CGPoint(x: w * 0.75, y: h * 1.28)
                        )
                        path.closeSubpath()
                    }
                    .fill(Color(red: 0.62, green: 0.12, blue: 0.0).opacity(0.75))
                }
            }
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 30,
                bottomTrailingRadius: 30, topTrailingRadius: 0
            ))
            .ignoresSafeArea(edges: .top)

            // Content sits at the bottom of the header, below safe area
            HStack(spacing: 14) {
                Button { appState.selectedTab = .maps } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(brand)
                        .frame(width: 48, height: 48)
                        .background(Color(red: 1, green: 0.88, blue: 0.84), in: Circle())
                }
                Text("Chat")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(height: 88)
        .shadow(color: brand.opacity(0.35), radius: 10, y: 5)
    }

    // MARK: - List

    private var chatList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.rooms) { room in
                    Button {
                        router.push(room.id)
                    } label: {
                        MatchRow(
                            room: room,
                            isUnseen: appState.isUnread(room, ownUserID: appState.currentUser?.id)
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.leading, 20)
                }
            }
        }
        .background(Color.white)
    }
}

// MARK: - Row

private struct MatchRow: View {
    let room: RoomDTO
    let isUnseen: Bool

    private let avatarSize: CGFloat = 56

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack(alignment: .topTrailing) {
                if let urlStr = room.peerPhotoURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        avatarPlaceholder
                    }
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder
                }
                if isUnseen {
                    Circle()
                        .fill(Color(hex: 0xD63200))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: 2, y: -2)
                }
            }

            // Name + preview
            VStack(alignment: .leading, spacing: 4) {
                Text(room.peerNickname)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(room.lastMessageText ?? room.eventName ?? "Tap to start chatting")
                    .font(.system(size: 14, weight: isUnseen ? .medium : .regular))
                    .foregroundStyle(isUnseen ? Color.primary.opacity(0.75) : .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Timestamp
            if let date = room.updatedAt ?? room.createdAt {
                Text(date.chatTimestamp)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(isUnseen ? Color(hex: 0xFFF5F2) : Color.white)
        .contentShape(Rectangle())
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: avatarSize, height: avatarSize)
            Text(String(room.peerNickname.prefix(1)).uppercased())
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Preview

#Preview {
    let now = Date()
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
    let tuesday  = Calendar.current.date(byAdding: .day, value: -2, to: now)!

    let mockRooms: [RoomDTO] = [
        RoomDTO(id: UUID(), codeRoom: "R1", peerUserID: UUID(), peerNickname: "Acing",
                peerAge: 24, peerPhotoURL: nil, eventID: nil, eventName: nil,
                createdAt: now, updatedAt: now,
                lastMessageSenderID: nil,
                lastMessageText: "kamu sama sama ngeping! coba saling chat",
                isInitiator: false),
        RoomDTO(id: UUID(), codeRoom: "R2", peerUserID: UUID(), peerNickname: "Ja Morant",
                peerAge: 26, peerPhotoURL: nil, eventID: nil, eventName: nil,
                createdAt: now, updatedAt: now,
                lastMessageSenderID: nil,
                lastMessageText: "Siap bro kita ketemuan di hall ya",
                isInitiator: true),
        RoomDTO(id: UUID(), codeRoom: "R3", peerUserID: UUID(), peerNickname: "Jessica Dava",
                peerAge: 22, peerPhotoURL: nil, eventID: nil, eventName: nil,
                createdAt: now, updatedAt: now,
                lastMessageSenderID: nil,
                lastMessageText: "Salken Besaya, yuk ke lobi",
                isInitiator: false),
        RoomDTO(id: UUID(), codeRoom: "R4", peerUserID: UUID(), peerNickname: "Nunez",
                peerAge: 28, peerPhotoURL: nil, eventID: nil, eventName: nil,
                createdAt: tuesday, updatedAt: tuesday,
                lastMessageSenderID: nil,
                lastMessageText: "See you next time yaa",
                isInitiator: false),
    ]

    NavigationStack {
        MatchesView(viewModel: MatchesViewModel(rooms: mockRooms))
    }
    .environment(AppState())
    .environment(NavigationRouter())
}

// MARK: - Date helper

private extension Date {
    var chatTimestamp: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f.string(from: self)
        } else if cal.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            let f = DateFormatter()
            f.dateFormat = "EEE"
            return f.string(from: self)
        }
    }
}
