import SwiftUI

struct RoomView: View {
    let roomID: UUID
    @State private var viewModel = RoomViewModel()
    @Environment(NavigationRouter.self) private var router
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider().opacity(0.2)
            messageList
            uwbStrip
            composer
        }
        .background(Color.peach.opacity(0.1).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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
        }
        .onChange(of: viewModel.messages.last?.timestamp) { _, latest in
            if let latest { appState.markRoomSeen(roomID: roomID, upTo: latest) }
        }
        .onDisappear {
            if let latest = viewModel.messages.last?.timestamp {
                appState.markRoomSeen(roomID: roomID, upTo: latest)
            }
            viewModel.cleanup()
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(alignment: .center) {
            Button { router.pop() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.terracotta)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            VStack(spacing: 4) {
                Circle()
                    .fill(Color.coral.opacity(0.25))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Text(String(viewModel.room?.peerNickname.prefix(1) ?? "?").uppercased())
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.terracotta)
                    }
                Text(viewModel.room?.peerNickname ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 8)
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
            HStack(alignment: .bottom, spacing: 6) {
                Spacer(minLength: 60)
                Text(time)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(.tertiaryLabel))
                Text(msg.message)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.coral,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        } else {
            HStack(alignment: .bottom, spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(msg.message)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.terracotta)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color(.systemGray6),
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Text(time)
                        .font(.system(size: 10))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .padding(.leading, 6)
                }
                Spacer(minLength: 60)
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
        HStack(spacing: 14) {
            TextField("chat something brother", text: $viewModel.draft, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...5)
                .focused($isComposerFocused)

            Button { } label: {
                Image(systemName: "mic")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(.tertiaryLabel))
            }

            Button {
                Task { await viewModel.send() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                     ? Color(.tertiaryLabel) : Color.coral)
                    .rotationEffect(.degrees(45))
            }
            .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground).shadow(.drop(radius: 0, y: -0.5)))
        .overlay(alignment: .top) { Divider().opacity(0.15) }
    }
}

