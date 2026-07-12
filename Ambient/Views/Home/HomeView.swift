import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    // Override for callers without a real presentation context (e.g. in-place overlay); falls back to dismiss.
    var onDismiss: (() -> Void)? = nil
    @Environment(AppState.self) private var appState
    @Environment(NavigationRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var selectedUser: NearbyUser? = nil
    @State private var showNotificationLog = false
    @State private var pendingSelectedUser: NearbyUser? = nil

    var body: some View {
        ZStack(alignment: .top) {
            if viewModel.isConnected {
                connectedContent
            } else {
                TapToConnectView(isConnecting: viewModel.isConnecting) {
                    Task { await viewModel.connect(appState: appState) }
                }
                .ignoresSafeArea()
            }

            header
        }
        .navigationDestination(for: UUID.self) { roomID in
            RoomView(roomID: roomID)
        }
        .onAppear {
            Task { await viewModel.start(appState: appState) }
        }
        .task {
            // Fast, reliable chat-bubble badge — polls /matches every 5s while radar is
            // visible and recomputes the unread set directly, the same way the chat list
            // does. SwiftUI auto-cancels this when HomeView disappears.
            let ownUserID = appState.currentUser?.id
            while !Task.isCancelled {
                await viewModel.refreshUnread(appState: appState, ownUserID: ownUserID)
                try? await Task.sleep(for: .seconds(5))
            }
        }
        .onDisappear {
            // Without this, tab-switching away leaves usersTask/eventsTask running as zombie consumers.
            viewModel.stop()
        }
        .sheet(item: $selectedUser) { user in
            RadarCardSheet(user: user) {
                Task { await viewModel.sendPing(to: user, appState: appState) }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showNotificationLog, onDismiss: {
            if let user = pendingSelectedUser {
                pendingSelectedUser = nil
                selectedUser = user
            }
        }) {
            PingNotificationLogSheet(
                pings: viewModel.receivedPings,
                matches: viewModel.recentMatches,
                nearbyUsers: viewModel.nearbyUsers,
                onSelectUser: { user in pendingSelectedUser = user },
                onSelectMatch: {
                    showNotificationLog = false
                    appState.selectedTab = .bookmarks
                }
            )
        }
        .onChange(of: viewModel.radarDisarmed) { _, disarmed in
            if disarmed {
                Task { await checkout() }
            }
        }
        .onChange(of: appState.shouldAutoConnectRadar) { _, should in
            if should {
                appState.shouldAutoConnectRadar = false
                Task { await viewModel.connect(appState: appState) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mutualMatchCreated)) { note in
            // Back Tap ping completed a match. Like the in-app sendPing completer
            // path, this no longer auto-navigates — just banner + notify log, same
            // as every other match path.
            guard let roomID = note.object as? UUID else { return }
            let peerUserID = note.userInfo?["peerUserID"] as? UUID
            Task { await viewModel.handleCompletedMatch(roomID: roomID, peerUserID: peerUserID) }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Check Out

    // leaveRadar clears appState.activeEvent — MainTabView's onChange
    // detects this and pops the maps router back to EventMapView.
    private func checkout() async {
        await viewModel.leaveRadar(appState: appState)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                // Back — HIG style, black icon
                Button { onDismiss?() ?? dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemBackground).opacity(0.92), in: Circle())
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                }

                Spacer()

                // Right: bell + checkout — HIG style, black icons
                HStack(spacing: Spacing.sm) {
                    Button { showNotificationLog = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.primary)
                                .frame(width: 44, height: 44)
                                .background(Color(.systemBackground).opacity(0.92), in: Circle())
                                .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                            if !viewModel.receivedPings.isEmpty || !viewModel.recentMatches.isEmpty {
                                Circle()
                                    .fill(Color.coral)
                                    .frame(width: 10, height: 10)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }

                    Button { Task { await checkout() } } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemBackground).opacity(0.92), in: Circle())
                            .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            // Toast
            if let banner = viewModel.banner {
                HStack(spacing: 6) {
                    switch banner.kind {
                    case .pingSent:
                        Text("🐝").font(.system(size: 15))
                    case .match:
                        Image(systemName: "heart.fill")
                            .font(.system(size: 13, weight: .semibold))
                    case .ping:
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(banner.text)
                        .font(.titleSmall)
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(banner.kind == .pingSent ? Color.terracotta : .white)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    banner.kind == .match ? Color.successGreen :
                    banner.kind == .pingSent ? Color.white :
                    Color.coral,
                    in: Capsule()
                )
                .shadow(color: .black.opacity(banner.kind == .pingSent ? 0.08 : 0), radius: 8, y: 2)
                .frame(maxWidth: 280)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.banner)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Connected content

    private var connectedContent: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: Spacing.md) {
                // Space for header (44pt nav bar + optional toast row)
                Spacer(minLength: 60)

                RadarView(
                    users: viewModel.nearbyUsers,
                    onTapUser: { user in
                        viewModel.focus(user, appState: appState)
                        selectedUser = user
                    }
                )
                .padding(.horizontal, Spacing.lg)

                Spacer()
            }

            // Chat floating button — bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button { appState.selectedTab = .bookmarks } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(Color.black)
                                .frame(width: 52, height: 52)
                                .background(Color(.systemBackground), in: Circle())
                                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                            if appState.hasUnseenMatches {
                                Circle()
                                    .fill(Color.coral)
                                    .frame(width: 10, height: 10)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 32)
                }
            }

            if !viewModel.receivedPings.isEmpty {
                pingCarousel
                    .padding(.bottom, 80)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Explicit opaque backing — an in-place overlay doesn't get one for free like fullScreenCover did.
        .background(Color.peach.opacity(0.15))
        .background(Color.white)
        .ignoresSafeArea()
    }

    private var pingCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                ForEach(viewModel.receivedPings) { ping in
                    PingNotificationCard(ping: ping) {
                        if let user = viewModel.nearbyUsers.first(where: { $0.id == ping.fromUserID }) {
                            viewModel.focus(user, appState: appState)
                            selectedUser = user
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.bottom, Spacing.lg)
    }

}

// MARK: - RadarCardSheet

private struct RadarCardSheet: View {
    let user: NearbyUser
    var onPing: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xl)

            // Avatar
            ZStack {
                Circle()
                    .fill(Color.apricot)
                    .frame(width: 80, height: 80)
                if let urlStr = user.photoURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        avatarInitial
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    avatarInitial
                }
            }

            Spacer().frame(height: Spacing.lg)

            Text(user.displayLabel)
                .font(.system(size: 22, weight: .bold))

            Spacer().frame(height: Spacing.sm)

            if let interests = user.interests, !interests.isEmpty {
                Text(interests.joined(separator: " • "))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
            }

            if let status = user.status, !status.isEmpty {
                Spacer().frame(height: Spacing.xl)
                VStack(spacing: Spacing.sm) {
                    Text("What they're up to?")
                        .font(.system(size: 17, weight: .semibold))
                    Text(status)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xxl)
                }
            }

            Spacer().frame(height: Spacing.xl)

            Button {
                onPing()
                dismiss()
            } label: {
                Text("Say Hello!")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Spacing.xxl)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var avatarInitial: some View {
        Text(String(user.nickname.prefix(1)).uppercased())
            .font(.system(.title, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.terracotta)
    }

    private var distanceLabel: String {
        if user.distance < 1 { return String(format: "~%.0f cm away", user.distance * 100) }
        return String(format: "~%.1f m away", user.distance)
    }
}

// MARK: - PingNotificationCard

private struct PingNotificationCard: View {
    let ping: PingNotificationDTO
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                Circle()
                    .fill(Color.apricot)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(ping.fromNickname.prefix(1)).uppercased())
                            .font(.titleLarge)
                            .foregroundStyle(Color.terracotta)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(ping.fromNickname)
                            .font(.titleSmall)
                            .foregroundStyle(Color.terracotta)
                        Spacer()
                        Text(ping.createdAt.abbreviatedRelative)
                            .font(.labelSmall)
                            .foregroundStyle(.secondary)
                    }
                    Text("Has pinged at you! 👋")
                        .font(.bodyMedium)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(Spacing.md)
            .frame(width: 300)
            .background(.white, in: RoundedRectangle(cornerRadius: Radius.card))
            .shadow(color: Color.terracotta.opacity(0.12), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ping Notification Log

private struct PingNotificationLogSheet: View {
    let pings: [PingNotificationDTO]
    let matches: [RoomDTO]
    let nearbyUsers: [NearbyUser]
    var onSelectUser: (NearbyUser) -> Void
    var onSelectMatch: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, Spacing.md)

            Text("Notifications")
                .font(.system(size: 17, weight: .semibold))
                .padding(.vertical, Spacing.md)

            Divider()

            if pings.isEmpty && matches.isEmpty {
                ContentUnavailableView(
                    "Nothing Yet",
                    systemImage: "bell.slash",
                    description: Text("Pings and matches will appear here.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        if !matches.isEmpty {
                            Section {
                                ForEach(matches) { room in
                                    Button {
                                        onSelectMatch()
                                        dismiss()
                                    } label: {
                                        MatchLogRow(room: room)
                                    }
                                    .buttonStyle(.plain)
                                    Divider().padding(.leading, 72)
                                }
                            } header: {
                                LogSectionHeader(title: "Matches")
                            }
                        }
                        if !pings.isEmpty {
                            Section {
                                ForEach(pings) { ping in
                                    let nearbyUser = nearbyUsers.first { $0.id == ping.fromUserID }
                                    Button {
                                        if let user = nearbyUser {
                                            onSelectUser(user)
                                            dismiss()
                                        }
                                    } label: {
                                        PingLogRow(ping: ping, isNearby: nearbyUser != nil)
                                    }
                                    .buttonStyle(.plain)
                                    Divider().padding(.leading, 72)
                                }
                            } header: {
                                LogSectionHeader(title: "Pings")
                            }
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

private struct LogSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(.white)
    }
}

private struct MatchLogRow: View {
    let room: RoomDTO

    var body: some View {
        HStack(spacing: Spacing.md) {
            if let urlStr = room.peerPhotoURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    matchAvatarPlaceholder
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                matchAvatarPlaceholder
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(room.peerNickname), \(NearbyUser.generation(for: room.peerAge))")
                    .font(.system(size: 15, weight: .semibold))
                Text("You matched! Tap to open chat 💬")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var matchAvatarPlaceholder: some View {
        Circle()
            .fill(Color.successGreen.opacity(0.25))
            .frame(width: 48, height: 48)
            .overlay(
                Text(String(room.peerNickname.prefix(1)).uppercased())
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.terracotta)
            )
    }
}

private struct PingLogRow: View {
    let ping: PingNotificationDTO
    let isNearby: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            if let urlStr = ping.fromPhotoURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    pingAvatarPlaceholder
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                pingAvatarPlaceholder
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(ping.fromNickname)
                    .font(.system(size: 15, weight: .semibold))
                Text("Pinged you 👋")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(ping.createdAt.abbreviatedRelative)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                if isNearby {
                    Text("Nearby")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.successGreen)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .opacity(isNearby ? 1 : 0.5)
    }

    private var pingAvatarPlaceholder: some View {
        Circle()
            .fill(Color.apricot)
            .frame(width: 48, height: 48)
            .overlay(
                Text(String(ping.fromNickname.prefix(1)).uppercased())
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.terracotta)
            )
    }
}

// MARK: - Date helpers

private extension Date {
    var abbreviatedRelative: String {
        let seconds = max(0, Date().timeIntervalSince(self))
        switch seconds {
        case ..<60: return "just now"
        case ..<3600: return "\(Int(seconds / 60)) min ago"
        case ..<86400: return "\(Int(seconds / 3600)) hr ago"
        default: return "\(Int(seconds / 86400)) d ago"
        }
    }
}
