import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Environment(AppState.self) private var appState
    @Environment(NavigationRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var selectedUser: NearbyUser? = nil

    var body: some View {
        ZStack(alignment: .top) {
            if viewModel.isConnected {
                connectedContent
            } else {
                TapToConnectView(isConnecting: viewModel.isConnecting) { status in
                    Task {
                        if let status { await viewModel.updateStatus(status) }
                        await viewModel.connect(appState: appState)
                    }
                }
                .ignoresSafeArea()
            }

            header
        }
        .navigationDestination(for: UUID.self) { roomID in
            RoomView(roomID: roomID)
        }
        .task {
            viewModel.start(appState: appState)
        }
        .onDisappear { viewModel.stop() }
        .sheet(item: $selectedUser) { user in
            RadarCardSheet(user: user) {
                Task { await viewModel.sendPing(to: user, appState: appState) }
            }
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
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
        .onReceive(NotificationCenter.default.publisher(for: .mutualMatchCreated)) { note in
            if let roomID = note.object as? UUID { router.push(roomID) }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
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
        HStack {
            // Back — dismiss radar without checking out
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(viewModel.isConnected ? Color.terracotta : .white)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(viewModel.isConnected ? 1 : 0.18), in: Circle())
            }

            Spacer()

            // Event name badge
            if let event = appState.activeEvent {
                Text(event.name)
                    .font(.labelSmall)
                    .lineLimit(1)
                    .foregroundStyle(viewModel.isConnected ? Color.terracotta : .white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(.white.opacity(viewModel.isConnected ? 1 : 0.18), in: Capsule())
                    .frame(maxWidth: 160)
            }

            Spacer()

            // Check Out — fully leaves the event
            Button {
                Task { await checkout() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Check Out")
                        .font(.labelLarge)
                }
                .foregroundStyle(viewModel.isConnected ? Color.terracotta : .white)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(.white.opacity(viewModel.isConnected ? 1 : 0.18), in: Capsule())
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

                if let banner = viewModel.banner {
                    bannerView(banner)
                }

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

    private func bannerView(_ banner: HomeViewModel.Banner) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: banner.kind == .match ? "heart.fill" : "dot.radiowaves.left.and.right")
            Text(banner.text).font(.titleSmall)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(banner.kind == .match ? Color.successGreen : Color.coral, in: Capsule())
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - RadarCardSheet

private struct RadarCardSheet: View {
    let user: NearbyUser
    var onPing: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                Circle().fill(Color.apricot).frame(width: 64, height: 64)
                Text(String(user.nickname.prefix(1)).uppercased())
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.terracotta)
            }
            .padding(.top, Spacing.xxl)

            Text(user.displayLabel)
                .font(.headlineSmall)

            if user.hasRealPosition {
                Text(distanceLabel)
                    .font(.bodyMedium)
                    .foregroundStyle(.secondary)
            } else {
                Text("Locating…").font(.bodyMedium).foregroundStyle(.secondary)
            }

            Button {
                onPing()
                dismiss()
            } label: {
                Label("Ping", systemImage: "dot.radiowaves.left.and.right")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Spacing.xxl)

            Spacer()
        }
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
