import SwiftUI

struct RoomView: View {
    let roomID: UUID
    @State private var viewModel = RoomViewModel()
    @Environment(NavigationRouter.self) private var router
<<<<<<< HEAD
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
=======

    var body: some View {
        VStack(spacing: 0) {
            uwbBanner
            messageList
            composer
        }
        .navigationTitle(viewModel.room?.peerNickname ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading && viewModel.room == nil {
>>>>>>> c5f4022 (Iniatial Commit)
                ProgressView()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
<<<<<<< HEAD
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { router.pop() }
        }
        .task(id: roomID) {
            await viewModel.loadRoom(id: roomID)
=======
        .task(id: roomID) {
            await viewModel.load(id: roomID)
>>>>>>> c5f4022 (Iniatial Commit)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

<<<<<<< HEAD
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
=======
    @ViewBuilder
    private var uwbBanner: some View {
        if let distance = viewModel.peerDistance {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "location.north.circle.fill")
                    .rotationEffect(.radians(Double(viewModel.peerDirection ?? 0)))
                    .foregroundStyle(Color.coral)
                Text(String(format: "%.1fm away", distance))
                    .font(.labelLarge)
                    .foregroundStyle(Color.terracotta)
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(Color.peach)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(viewModel.messages) { message in
                        bubble(for: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func bubble(for message: ChatMessageDTO) -> some View {
        let isMine = message.senderUserID == viewModel.myUserID
        return HStack {
            if isMine { Spacer(minLength: 40) }
            Text(message.message)
                .font(.bodyMedium)
                .foregroundStyle(isMine ? .white : Color.terracotta)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isMine ? Color.coral : Color.peach,
                            in: RoundedRectangle(cornerRadius: Radius.chip))
            if !isMine { Spacer(minLength: 40) }
        }
    }

    private var composer: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Message", text: $viewModel.draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await viewModel.send() }
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }
>>>>>>> c5f4022 (Iniatial Commit)
}
