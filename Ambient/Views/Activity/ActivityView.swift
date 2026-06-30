import SwiftUI

struct ActivityView: View {
    @State private var viewModel = ActivityViewModel()

    var body: some View {
        List {
            Section("Join Requests") {
                if viewModel.joinRequests.isEmpty {
                    Text("No join requests yet")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(viewModel.joinRequests) { request in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Request to room")
                                    .font(.headline)
                                Spacer()
                                statusBadge(for: request)
                            }
                            Text(request.createdAt.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Matches") {
                if viewModel.matches.isEmpty {
                    Text("No matches yet")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(viewModel.matches) { match in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("New match")
                                .font(.headline)
                            Text(match.matchedAt.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Activity")
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
        .task {
            await viewModel.loadActivity()
        }
        .refreshable {
            await viewModel.loadActivity()
        }
    }

    @ViewBuilder
    private func statusBadge(for request: JoinRequestDTO) -> some View {
        let (label, color): (String, Color) = {
            switch request.status {
            case "pending":  return ("Pending",  .orange)
            case "approved": return ("Approved", .green)
            default:         return ("Expired",  .secondary)
            }
        }()

        Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
