import SwiftUI

struct RoomView: View {
    let roomID: UUID
    @State private var viewModel = RoomViewModel()
    @Environment(NavigationRouter.self) private var router
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @FocusState private var isComposerFocused: Bool

    private let brand = Color(hex: 0xD63200)

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            messageList
            uwbStrip
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea(.all, edges: .bottom))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(brand, for: .navigationBar)
        .overlay {
            if viewModel.isLoading && viewModel.room == nil {
                ProgressView()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task(id: roomID) {
            await viewModel.load(id: roomID)
        }
        .onAppear {
            // Optimistically clear the badge on entry; the message-timestamp watchers
            // below then pin the watermark to the newest message (server clock) so it
            // survives clock skew and covers messages that arrive while we're reading.
            appState.markRoomSeen(roomID: roomID, upTo: Date())
            appState.openRoomID = roomID
        }
        .onChange(of: viewModel.messages.last?.timestamp) { _, latest in
            if let latest { appState.markRoomSeen(roomID: roomID, upTo: latest) }
        }
        .onDisappear {
            if let latest = viewModel.messages.last?.timestamp {
                appState.markRoomSeen(roomID: roomID, upTo: latest)
            }
            if appState.openRoomID == roomID { appState.openRoomID = nil }
            viewModel.cleanup()
        }
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
            HStack(spacing: 12) {
                Button { router.pop() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(brand)
                        .frame(width: 48, height: 48)
                        .background(Color(red: 1, green: 0.88, blue: 0.84), in: Circle())
                }

                if let urlStr = viewModel.room?.peerPhotoURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        chatAvatarPlaceholder
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    chatAvatarPlaceholder
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.room?.peerNickname ?? "")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("Online")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(height: 88)
        .shadow(color: brand.opacity(0.35), radius: 10, y: 5)
    }

    private var chatAvatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 44, height: 44)
            Text(String(viewModel.room?.peerNickname.prefix(1) ?? "?").uppercased())
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    systemMessage("This chat has been added to the chat list")
                    ForEach(viewModel.messages) { msg in
                        bubble(for: msg).id(msg.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onTapGesture { isComposerFocused = false }
            }
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func systemMessage(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }

    @ViewBuilder
    private func bubble(for msg: ChatMessageDTO) -> some View {
        let isMine = msg.senderUserID == viewModel.myUserID
        let time = msg.timestamp.formatted(date: .omitted, time: .shortened)

        if isMine {
            // Outgoing — bubble on right, time beside on the left
            HStack(alignment: .bottom, spacing: 5) {
                Spacer(minLength: 40)
                Text(time)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(.tertiaryLabel))
                Text(msg.message)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(hex: 0x336F7A),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        } else {
            // Incoming — bubble on left, time beside on the right
            HStack(alignment: .bottom, spacing: 5) {
                Text(msg.message)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(.systemBackground),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(time)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(.tertiaryLabel))
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - UWB / connection strip (above composer)

    @ViewBuilder
    private var uwbStrip: some View {
        let peer = viewModel.room?.peerNickname ?? ""
        HStack {
            if let distance = viewModel.peerDistance {
                let cm = Int(distance * 100)
                Text("\(cm) cm from \(peer)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.terracotta)
            } else if viewModel.uwbPermissionPending {
                Text("Enable Nearby Interactions to use UWB")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.coral)
            } else if viewModel.isUWBSearching {
                Text("Connecting with \(peer)...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else if viewModel.isWSConnected {
                Text("Waiting for \(peer) to open chat")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                Text("Connecting...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color(.systemGray6).opacity(0.6))
        .animation(.easeInOut(duration: 0.2), value: viewModel.peerDistance != nil)
    }

    // MARK: - Composer

    private var composer: some View {
        let isEmpty = viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return HStack(spacing: 10) {
            TextField("Chat something...", text: $viewModel.draft, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...5)
                .focused($isComposerFocused)

            Button {
                Task { await viewModel.send() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(isEmpty ? Color(.systemGray3) : brand, in: Circle())
                    .rotationEffect(.degrees(45))
            }
            .disabled(isEmpty)
            .animation(.easeInOut(duration: 0.15), value: isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Matches") {
    NavigationStack {
        MatchesView()
            .environment(NavigationRouter())
            .environment(AppState())
    }
}
