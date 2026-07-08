import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
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
                nearbyUsers: viewModel.nearbyUsers,
                onSelectUser: { user in pendingSelectedUser = user }
            )
        }
        .onChange(of: viewModel.pendingRoomID) { _, roomID in
            if let roomID {
                viewModel.pendingRoomID = nil
                router.push(roomID)
            }
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
            guard let roomID = note.object as? UUID else { return }
            let peerUserID = note.userInfo?["peerUserID"] as? UUID
            if let peerUserID { viewModel.receivedPings.removeAll { $0.fromUserID == peerUserID } }
            Task {
                let resolved = await viewModel.resolveRoom(roomID: roomID, peerUserID: peerUserID)
                router.push(resolved)
            }
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
        HStack(spacing: Spacing.sm) {
            // Back — dismiss radar without checking out
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(viewModel.isConnected ? Color.terracotta : .white)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(viewModel.isConnected ? 1 : 0.18), in: Circle())
            }

            Spacer()

            // Center: banner when active, otherwise event name
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
                    Text(banner.text).font(.titleSmall)
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
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if let event = appState.activeEvent {
                Text(event.name)
                    .font(.labelSmall)
                    .lineLimit(1)
                    .foregroundStyle(viewModel.isConnected ? Color.terracotta : .white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(.white.opacity(viewModel.isConnected ? 1 : 0.18), in: Capsule())
                    .frame(maxWidth: 140)
            }

            Spacer()

            // Right: notification + chat + check out
            HStack(spacing: Spacing.xs) {
                // Notification bell with badge dot
                Button { showNotificationLog = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(viewModel.isConnected ? Color.terracotta : .white)
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(viewModel.isConnected ? 1 : 0.18), in: Circle())
                        if !viewModel.receivedPings.isEmpty {
                            Circle()
                                .fill(Color.coral)
                                .frame(width: 10, height: 10)
                                .offset(x: 2, y: -2)
                        }
                    }
                }

                // Chat — switches to matches tab
                Button { appState.selectedTab = .bookmarks } label: {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(viewModel.isConnected ? Color.terracotta : .white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(viewModel.isConnected ? 1 : 0.18), in: Circle())
                }

                // Check out
                Button { Task { await checkout() } } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(viewModel.isConnected ? Color.terracotta : .white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(viewModel.isConnected ? 1 : 0.18), in: Circle())
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Connected content

    private var connectedContent: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: Spacing.md) {
                Spacer(minLength: 56)

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

            if !viewModel.receivedPings.isEmpty {
                pingCarousel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.peach.opacity(0.15))
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
    let nearbyUsers: [NearbyUser]
    var onSelectUser: (NearbyUser) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, Spacing.md)

            Text("Pings")
                .font(.system(size: 17, weight: .semibold))
                .padding(.vertical, Spacing.md)

            Divider()

            if pings.isEmpty {
                ContentUnavailableView(
                    "No Pings Yet",
                    systemImage: "bell.slash",
                    description: Text("When someone pings you, they'll appear here.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
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
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

private struct PingLogRow: View {
    let ping: PingNotificationDTO
    let isNearby: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(Color.apricot)
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(ping.fromNickname.prefix(1)).uppercased())
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.terracotta)
                )

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
