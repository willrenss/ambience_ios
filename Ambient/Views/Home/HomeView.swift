import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Environment(AppState.self) private var appState
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

            Spacer()
        }
    }

    private func formatDistance(_ meters: Float) -> String {
        if meters < 1.0 { return String(format: "%.0f cm away", meters * 100) }
        return String(format: "%.1f m away", meters)
    }
}
