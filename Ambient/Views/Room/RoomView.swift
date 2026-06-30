import SwiftUI

struct RoomView: View {
    let roomID: UUID
    @State private var viewModel = RoomViewModel()
    @Environment(NavigationRouter.self) private var router
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section("Members (\(viewModel.members.count))") {
                ForEach(viewModel.members) { member in
                    HStack(spacing: 12) {
                        initialsCircle(for: member.displayName)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.displayName)
                                .font(.headline)
                            Text("Joined \(member.joinedAt.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if viewModel.isCreator && !viewModel.pendingRequests.isEmpty {
                Section("Join Requests (\(viewModel.pendingRequests.count))") {
                    ForEach(viewModel.pendingRequests) { request in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Request")
                                    .font(.headline)
                                Text(request.expiresAt.formatted(.relative(presentation: .named)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                Button {
                                    Task { await viewModel.declineRequest(request.id) }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                        .font(.title2)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    Task { await viewModel.approveRequest(request.id) }
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.title2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { await viewModel.leaveRoom() }
                } label: {
                    Label("Leave Room", systemImage: "rectangle.portrait.and.arrow.right")
                }

                if viewModel.isCreator {
                    Button(role: .destructive) {
                        Task { await viewModel.dissolveRoom() }
                    } label: {
                        Label("Dissolve Room", systemImage: "xmark.circle")
                    }
                }
            }
        }
        .navigationTitle("Room")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { router.pop() }
        }
        .task(id: roomID) {
            await viewModel.loadRoom(id: roomID)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    private func initialsCircle(for name: String) -> some View {
        let initial = String(name.prefix(1)).uppercased()
        return ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 40, height: 40)
            Text(initial)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.tint)
        }
    }
}
