import Observation
import Foundation

@Observable
@MainActor
final class RoomViewModel {
    var room: RoomDTO? = nil
    var members: [RoomMemberDTO] = []
    var pendingRequests: [JoinRequestDTO] = []
    var isCreator: Bool = false
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var shouldDismiss: Bool = false

    private var streamTask: Task<Void, Never>? = nil

    func loadRoom(id: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let state = try await RoomService.shared.fetchRoomState(id: id)
            members = state.members
            applySocketState(state)
            await connectWebSocket(roomID: id)
        } catch {
            errorMessage = "Failed to load room."
        }
    }

    func leaveRoom() async {
        guard let id = room?.id else { return }
        do {
            try await RoomService.shared.leaveRoom(id: id)
            await RoomService.shared.disconnect()
            shouldDismiss = true
        } catch {
            errorMessage = "Failed to leave room."
        }
    }

    func dissolveRoom() async {
        guard let id = room?.id else { return }
        do {
            try await RoomService.shared.dissolveRoom(id: id)
            await RoomService.shared.disconnect()
            shouldDismiss = true
        } catch {
            errorMessage = "Failed to dissolve room."
        }
    }

    func approveRequest(_ id: UUID) async {
        do {
            try await JoinRequestService.shared.approveRequest(id: id)
            pendingRequests.removeAll { $0.id == id }
            HapticManager.shared.playSuccessHaptic()
        } catch {
            errorMessage = "Failed to approve request."
        }
    }

    func declineRequest(_ id: UUID) async {
        do {
            try await JoinRequestService.shared.declineRequest(id: id)
            pendingRequests.removeAll { $0.id == id }
        } catch {
            errorMessage = "Failed to decline request."
        }
    }

    func cleanup() {
        streamTask?.cancel()
        streamTask = nil
        Task { await RoomService.shared.disconnect() }
    }

    // MARK: - Private

    private func applySocketState(_ state: RoomStateDTO) {
        members = state.members
    }

    private func connectWebSocket(roomID: UUID) async {
        guard let token = KeychainHelper.shared.load(forKey: "auth_token") else { return }
        do {
            let stream = try await RoomService.shared.connectToRoom(id: roomID, token: token)
            streamTask = Task { @MainActor [weak self] in
                for await message in stream {
                    self?.handleSocketMessage(message)
                }
            }
        } catch {
            // WebSocket is best-effort; app still works via polling if needed.
        }
    }

    private func handleSocketMessage(_ message: RoomSocketMessage) {
        switch message.event {
        case "room_state":
            guard
                let data = message.payload.data(using: .utf8),
                let state = try? JSONDecoder().decode(RoomStateDTO.self, from: data)
            else { return }
            members = state.members

        case "join_request":
            guard
                let data = message.payload.data(using: .utf8),
                let request = try? JSONDecoder().decode(JoinRequestDTO.self, from: data)
            else { return }
            if !pendingRequests.contains(where: { $0.id == request.id }) {
                pendingRequests.append(request)
            }
            HapticManager.shared.playLightTap()

        case "room_dissolved":
            shouldDismiss = true

        default:
            break
        }
    }
}
