#if DEBUG
import SwiftUI

// MARK: - Mock data

private let _myID   = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
private let _peerID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
private let _roomID = UUID()

private let _messages: [ChatMessageDTO] = [
    .init(id: UUID(), roomID: _roomID, senderUserID: _peerID,
          message: "hey are you near the stage?",
          timestamp: Date().addingTimeInterval(-400)),
    .init(id: UUID(), roomID: _roomID, senderUserID: _myID,
          message: "yeah I just got here, left section near the speakers",
          timestamp: Date().addingTimeInterval(-300)),
    .init(id: UUID(), roomID: _roomID, senderUserID: _peerID,
          message: "cool! I'm by the merch booth, come find me 👋",
          timestamp: Date().addingTimeInterval(-200)),
    .init(id: UUID(), roomID: _roomID, senderUserID: _myID,
          message: "on my way!",
          timestamp: Date().addingTimeInterval(-90)),
    .init(id: UUID(), roomID: _roomID, senderUserID: _peerID,
          message: "btw the signal is kinda weak here",
          timestamp: Date().addingTimeInterval(-30)),
]

// MARK: - Preview shell (no services / no network)

struct RoomPreviewShell: View {
    let peerNickname: String
    let messages: [ChatMessageDTO]
    let uwbState: UWBPreviewState

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    enum UWBPreviewState: String, CaseIterable {
        case distance   = "Distance"
        case searching  = "Connecting"
        case waiting    = "Waiting"
        case permission = "Permission"
        case connecting = "Default"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.2)
            messageList
            strip
            composerBar
        }
        .background(Color.peach.opacity(0.1).ignoresSafeArea())
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            Button { } label: {
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
                        Text(String(peerNickname.prefix(1)).uppercased())
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.terracotta)
                    }
                Text(peerNickname)
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

    // MARK: Message list

    private var messageList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                Text("This chat has been added to the chat list")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                ForEach(messages) { msg in
                    bubble(for: msg)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func bubble(for msg: ChatMessageDTO) -> some View {
        let isMine = msg.senderUserID == _myID
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

    // MARK: UWB strip

    @ViewBuilder
    private var strip: some View {
        HStack {
            switch uwbState {
            case .distance:
                Text("142 cm from \(peerNickname)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.terracotta)
            case .searching:
                Text("Connecting with \(peerNickname)...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            case .waiting:
                Text("Waiting for \(peerNickname) to open chat")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            case .permission:
                Text("Enable Nearby Interactions to use UWB")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Open Settings") { }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.coral)
            case .connecting:
                Text("Connecting...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color(.systemGray6).opacity(0.6))
    }

    // MARK: Composer

    private var composerBar: some View {
        HStack(spacing: 14) {
            TextField("chat something brother", text: $draft, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...5)
                .focused($isFocused)

            Button { } label: {
                Image(systemName: "mic")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(.tertiaryLabel))
            }

            Button { } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                     ? Color(.tertiaryLabel) : Color.coral)
                    .rotationEffect(.degrees(45))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground).shadow(.drop(radius: 0, y: -0.5)))
        .overlay(alignment: .top) { Divider().opacity(0.15) }
    }
}

// MARK: - Canvas previews

#Preview("Distance (light)") {
    RoomPreviewShell(peerNickname: "Aria", messages: _messages, uwbState: .distance)
}

#Preview("Connecting") {
    RoomPreviewShell(peerNickname: "Aria", messages: _messages, uwbState: .searching)
}

#Preview("Permission needed") {
    RoomPreviewShell(peerNickname: "Aria", messages: _messages, uwbState: .permission)
}

#Preview("Waiting for peer") {
    RoomPreviewShell(peerNickname: "Aria", messages: _messages, uwbState: .waiting)
}

#Preview("Dark mode") {
    RoomPreviewShell(peerNickname: "Aria", messages: _messages, uwbState: .distance)
        .preferredColorScheme(.dark)
}
#endif
