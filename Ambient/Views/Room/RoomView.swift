import SwiftUI

struct RoomView: View {
    let roomID: UUID
    @State private var viewModel = RoomViewModel()
    @Environment(NavigationRouter.self) private var router

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
        .onDisappear {
            viewModel.cleanup()
        }
    }

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
}
