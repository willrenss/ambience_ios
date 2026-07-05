import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Environment(AppState.self) private var appState
<<<<<<< HEAD
    @State private var selectedUser: NearbyUser? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                if let venue = viewModel.currentVenue {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(venue.name).font(.headline)
                        Text(venue.address).font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Nearby").font(.headline).foregroundStyle(.secondary)
                }

                Spacer()

                if !viewModel.nearbyUsers.isEmpty {
                    Label("\(viewModel.nearbyUsers.count)", systemImage: "person.2.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.tint.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            if viewModel.isOpen {
                VStack(spacing: 12) {
                    // Wave banner
                    if let waver = viewModel.lastWaveFrom {
                        HStack(spacing: 8) {
                            Text("👋").font(.title3)
                            Text("\(waver) waved at you!")
                                .font(.subheadline.bold())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.15), in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    RadarView(
                        users: viewModel.nearbyUsers,
                        selfLabel: appState.currentUser?.displayName ?? "You",
                        onTapUser: { selectedUser = $0 }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    if viewModel.nearbyUsers.isEmpty {
                        Text("Scanning for people nearby…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Debug overlay
                    VStack(spacing: 2) {
                        let locating = viewModel.nearbyUsers.filter { !$0.hasRealPosition }.count
                        let withDir  = viewModel.nearbyUsers.filter { $0.direction != nil }.count
                        let total    = viewModel.nearbyUsers.count
                        if total > 0 {
                            Text("server:\(total) dir:\(withDir)/\(total) locating:\(locating)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.yellow.opacity(0.7))
                        }
                        if !viewModel.uwbDebugStatus.isEmpty {
                            Text(viewModel.uwbDebugStatus)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.cyan.opacity(0.6))
                        }
                        if !viewModel.gpsDebugStatus.isEmpty {
                            Text(viewModel.gpsDebugStatus)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.orange.opacity(0.6))
                        }
                    }
                    .padding(.horizontal)

                    // Ping button
                    Button {
                        Task { await viewModel.sendWave() }
                    } label: {
                        Label("Ping Nearby", systemImage: "hand.wave.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .padding(.horizontal, 32)

                    Spacer()
                }
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 52))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Toggle open below to discover\npeople nearby")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            }

            statusToggleBar
        }
        .navigationTitle("Nearby")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedUser) { user in
            UserProfileSheet(user: user)
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: .searchNearbyTriggered)) { _ in
            Task { await viewModel.handleSearchNearbyNotification() }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var statusToggleBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.isOpen ? "Open to connect" : "Closed")
                        .font(.headline)
                    Text(viewModel.isOpen ? "Others can discover you" : "You are invisible to others")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.isOpen },
                    set: { _ in Task { await viewModel.toggleStatus() } }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.green)
                .scaleEffect(1.2)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(.bar)
        }
    }
}

// MARK: - User profile sheet (shown on dot tap)

private struct UserProfileSheet: View {
    let user: NearbyUser
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.85))
                    .frame(width: 64, height: 64)
                Text(String(user.displayName.prefix(1)))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.top, 24)

            // Name + distance
            VStack(spacing: 4) {
                Text(user.displayName)
                    .font(.title3.bold())
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                    Text(formatDistance(user.distance))
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }

            // Wave button
            Button {
                dismiss()
            } label: {
                Label("Wave 👋", systemImage: "hand.wave.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
=======
    @Environment(NavigationRouter.self) private var router
    @State private var selectedUser: NearbyUser? = nil

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
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
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
                Task { await viewModel.leaveRadar(appState: appState) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mutualMatchCreated)) { note in
            if let roomID = note.object as? UUID { router.push(roomID) }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
    }

    // Shared across both the offline and connected states, matching the reference design.
    private var header: some View {
        HStack {
            Button {
                Task { await viewModel.leaveRadar(appState: appState) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.titleMedium)
                    .foregroundStyle(viewModel.isConnected ? Color.terracotta : .white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(viewModel.isConnected ? 1 : 0.15), in: Circle())
            }

            Spacer()

            HStack(spacing: Spacing.sm) {
                headerAvatar
                headerAvatar
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    private var headerAvatar: some View {
        Image(systemName: "person.fill")
            .foregroundStyle(viewModel.isConnected ? Color.terracotta : .white)
            .frame(width: 40, height: 40)
            .background(.white.opacity(viewModel.isConnected ? 1 : 0.15), in: Circle())
    }

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

// Ambient radar card (design system "Sophie, 24"). No public profile — this IS the profile.
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
>>>>>>> c5f4022 (Iniatial Commit)

            Spacer()
        }
    }

<<<<<<< HEAD
    private func formatDistance(_ meters: Float) -> String {
        if meters < 1.0 { return String(format: "%.0f cm away", meters * 100) }
        return String(format: "%.1f m away", meters)
=======
    // BLE distance is approximate — always prefix "~" per spec.
    private var distanceLabel: String {
        if user.distance < 1 { return String(format: "~%.0f cm away", user.distance * 100) }
        return String(format: "~%.1f m away", user.distance)
    }
}

// Bottom carousel card — no profile photos exist in the data model (User is
// nickname/birthdate/hometown only, no avatar upload), so the initial-letter
// bubble stands in for the photo shown in the reference design.
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
    // Abbreviated relative time ("4 hr ago") matching the reference design,
    // rather than RelativeDateTimeFormatter's unabbreviated "4 hours ago".
    var abbreviatedRelative: String {
        let seconds = max(0, Date().timeIntervalSince(self))
        switch seconds {
        case ..<60: return "just now"
        case ..<3600: return "\(Int(seconds / 60)) min ago"
        case ..<86400: return "\(Int(seconds / 3600)) hr ago"
        default: return "\(Int(seconds / 86400)) d ago"
        }
>>>>>>> c5f4022 (Iniatial Commit)
    }
}
