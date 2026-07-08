import SwiftUI

struct StatusIntentView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var statusText = ""
    @State private var isBusy = false
    @State private var myProfile: UserProfile? = nil
    @FocusState private var isTextEditorFocused: Bool

    /// Called with the non-empty trimmed status when "Get into Radar" is tapped.
    var onGetIntoRadar: (String) async -> Void

    private let maxLength = 100

    private var trimmed: String {
        statusText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Image("statusBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Back button
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)

                Spacer()

                // Profile card — own data
                profileCard
                    .padding(.horizontal, Spacing.xxl)

                Spacer().frame(height: Spacing.xxl)

                // Title
                Text("What Are You\nUp to?")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.primary)
                    .lineSpacing(2)
                    .padding(.horizontal, Spacing.xxl)

                Spacer().frame(height: Spacing.lg)

                // Text input
                ZStack(alignment: .bottomTrailing) {
                    ZStack(alignment: .topLeading) {
                        if statusText.isEmpty {
                            Text("Share what you're doing, looking for, or open to talk about...")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(.placeholderText))
                                .padding(.top, 10)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $statusText)
                            .font(.system(size: 14))
                            .frame(minHeight: 72, maxHeight: 90)
                            .scrollContentBackground(.hidden)
                            .background(.clear)
                            .focused($isTextEditorFocused)
                            .onChange(of: statusText) { _, new in
                                if new.count > maxLength {
                                    statusText = String(new.prefix(maxLength))
                                }
                            }
                    }
                    .padding(.bottom, 22)

                    Text("\(statusText.count)/\(maxLength)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
                .padding(Spacing.md)
                .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, Spacing.xxl)

                Spacer()

                // Get into Radar
                Button {
                    guard !trimmed.isEmpty, !isBusy else { return }
                    isBusy = true
                    Task {
                        await onGetIntoRadar(trimmed)
                        isBusy = false
                        dismiss()
                    }
                } label: {
                    Group {
                        if isBusy {
                            ProgressView().tint(.primary)
                        } else {
                            Text("Get into Radar")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(trimmed.isEmpty
                                                 ? Color.primary.opacity(0.35)
                                                 : Color.primary.opacity(0.75))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.white.opacity(trimmed.isEmpty ? 0.25 : 0.55), in: Capsule())
                }
                .disabled(trimmed.isEmpty || isBusy)
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, 48)
            }
        }
        .onTapGesture { isTextEditorFocused = false }
        .navigationBarHidden(true)
        .task {
            myProfile = try? await APIClient.shared.get("/me")
        }
    }

    // MARK: - Profile card

    private var profileCard: some View {
        HStack(spacing: Spacing.lg) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.apricot)
                    .frame(width: 56, height: 56)
                if let urlStr = myProfile?.photoURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        avatarInitial
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                } else {
                    avatarInitial
                }
            }

            // Name + interests
            VStack(alignment: .leading, spacing: 4) {
                if let profile = myProfile {
                    let suffix = profile.generation ?? ""
                    Text(suffix.isEmpty ? profile.nickname : "\(profile.nickname), \(suffix)")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)

                    if let interests = profile.interests, !interests.isEmpty {
                        Text(interests.prefix(3).joined(separator: " · "))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    // Skeleton placeholders while loading
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 100, height: 16)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 140, height: 12)
                }
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
    }

    private var avatarInitial: some View {
        Text(String((myProfile?.nickname ?? "?").prefix(1)).uppercased())
            .font(.system(size: 22, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.terracotta)
    }
}

struct StatusPatchBody: Encodable {
    let status: String
}
