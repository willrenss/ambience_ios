import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationRouter.self) private var router
    @State private var viewModel: ProfileViewModel?
    @State private var notificationsEnabled: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false

    @AppStorage("haptics_enabled") private var hapticsEnabled: Bool = true
    @AppStorage("uwb_enabled")     private var uwbEnabled: Bool = true

    // Inline edit state
    @State private var editingName = false
    @State private var editingHometown = false
    @State private var editName = ""
    @State private var editHometown = ""
    @State private var showInterestsPicker = false
    @State private var serverURL: String = ServerConfig.currentURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // MARK: Avatar
                avatarSection

                // MARK: Personal Data
                sectionCard("Personal Data") {
                    if let user = viewModel?.user {
                        ProfileRow("Name", value: user.nickname) {
                            editName = user.nickname
                            editingName = true
                        }
                        Divider().padding(.leading, Spacing.lg)
                        ProfileRow("Birthday", value: user.formattedBirthdate ?? "—")
                        Divider().padding(.leading, Spacing.lg)
                        ProfileRow("Hometown", value: user.hometown ?? "—") {
                            editHometown = user.hometown ?? ""
                            editingHometown = true
                        }
                        Divider().padding(.leading, Spacing.lg)
                        ProfileRow(
                            "Interests",
                            value: interestsSummary(user.interests),
                            disclosure: true
                        ) { showInterestsPicker = true }
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    }
                }

                // MARK: Permissions
                sectionCard("Permissions") {
                    HStack {
                        Text("GPS & Bluetooth Access")
                            .font(.system(size: 15))
                        Spacer()
                        Button("Open Settings") {
                            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, 14)

                    Divider().padding(.leading, Spacing.lg)

                    Toggle(isOn: $uwbEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("UWB Distance (Nearby Interaction)")
                                .font(.system(size: 15))
                            Text("Show exact distance when both users open the same chat")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, 14)
                    .tint(Color.coral)
                    .onChange(of: uwbEnabled) { _, enabled in
                        NearbyInteractionService.shared.isUWBEnabled = enabled
                    }

                    Divider().padding(.leading, Spacing.lg)

                    Toggle(isOn: $notificationsEnabled) {
                        Text("Notifications")
                            .font(.system(size: 15))
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, 14)
                    .tint(Color.successGreen)
                }

                // MARK: Developer (collapsible / subtle)
                sectionCard("Developer") {
                    HStack {
                        Text("Server URL")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                        TextField("http://…", text: $serverURL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 15))
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, 14)
                }

                // MARK: Sign Out
                Button(role: .destructive) {
                    Task { await viewModel?.signOut() }
                } label: {
                    Group {
                        if viewModel?.isLoading == true {
                            ProgressView()
                        } else {
                            Text("Sign Out")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.coral)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.white, in: RoundedRectangle(cornerRadius: Radius.card))
                }
                .disabled(viewModel?.isLoading == true)

            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.peach.opacity(0.15).ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        // Edit name alert
        .alert("Edit Name", isPresented: $editingName) {
            TextField("Nickname", text: $editName)
            Button("Save") { Task { await viewModel?.updateNickname(editName) } }
            Button("Cancel", role: .cancel) { }
        }
        // Edit hometown alert
        .alert("Edit Hometown", isPresented: $editingHometown) {
            TextField("City, Country", text: $editHometown)
            Button("Save") { Task { await viewModel?.updateHometown(editHometown) } }
            Button("Cancel", role: .cancel) { }
        }
        // Interests picker sheet
        .sheet(isPresented: $showInterestsPicker) {
            if let vm = viewModel {
                InterestsPickerSheet(viewModel: vm)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ProfileViewModel(appState: appState)
            }
            notificationsEnabled = UserDefaults.standard.bool(forKey: "notifications_enabled")
        }
        .onChange(of: notificationsEnabled) { _, new in
            UserDefaults.standard.set(new, forKey: "notifications_enabled")
        }
        .onChange(of: serverURL) { _, new in
            let t = new.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, URL(string: t) != nil else { return }
            ServerConfig.setURL(t)
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                isUploadingPhoto = true
                defer { isUploadingPhoto = false; selectedPhotoItem = nil }
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let compressed = image.resizedForUpload()
                else { return }
                await viewModel?.uploadPhoto(compressed)
            }
        }
    }

    // MARK: - Avatar section

    private var avatarSection: some View {
        VStack(spacing: Spacing.md) {
            ZStack(alignment: .bottomTrailing) {
                if let url = viewModel?.user?.photoURL.flatMap(URL.init) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        avatarCircle
                    }
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                } else {
                    avatarCircle
                }

                // PhotosPicker runs out-of-process — no NSPhotoLibraryUsageDescription/permission prompt needed.
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(Color.terracotta)
                            .frame(width: 28, height: 28)
                        if isUploadingPhoto {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .disabled(isUploadingPhoto)
                .offset(x: 2, y: 2)
            }

            if let user = viewModel?.user {
                // Name + generation
                let gen = user.generation ?? ""
                Text(gen.isEmpty ? user.nickname : "\(user.nickname), \(gen)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                // Interests with dots
                if let interests = user.interests, !interests.isEmpty {
                    Text(interests.joined(separator: " · "))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, Spacing.xxl)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    private var avatarCircle: some View {
        ZStack {
            Circle()
                .fill(Color.apricot)
                .frame(width: 88, height: 88)
            Text(String((viewModel?.user?.nickname ?? "?").prefix(1)).uppercased())
                .font(.system(size: 34, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.terracotta)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionCard(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(.white, in: RoundedRectangle(cornerRadius: Radius.card))
        }
    }

    private func interestsSummary(_ interests: [String]?) -> String {
        guard let interests, !interests.isEmpty else { return "—" }
        if interests.count == 1 { return interests[0] }
        return "\(interests[0]) +\(interests.count - 1)"
    }
}

// MARK: - Profile Row

private struct ProfileRow: View {
    let label: String
    let value: String
    var disclosure: Bool = false
    var onTap: (() -> Void)? = nil

    init(_ label: String, value: String, disclosure: Bool = false, onTap: (() -> Void)? = nil) {
        self.label = label
        self.value = value
        self.disclosure = disclosure
        self.onTap = onTap
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                Spacer()
                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if disclosure {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
}

// MARK: - Interests Picker Sheet

private struct InterestsPickerSheet: View {
    let viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var isSaving = false
    @State private var searchText = ""

    private var filtered: [Interest] {
        searchText.trimmingCharacters(in: .whitespaces).isEmpty
            ? viewModel.allInterests
            : viewModel.allInterests.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                FlowLayout(spacing: 10) {
                    ForEach(filtered) { interest in
                        let isOn = selected.contains(interest.name)
                        Button {
                            if isOn { selected.remove(interest.name) }
                            else { selected.insert(interest.name) }
                        } label: {
                            Text(interest.name)
                                .font(.system(size: 14, weight: isOn ? .semibold : .regular))
                                .foregroundStyle(isOn ? Color.terracotta : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    isOn ? Color.apricot.opacity(0.5) : Color(.systemGray6),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.lg)
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search interests...")
            .navigationTitle("Interests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // TODO: wire up PATCH /me/interests endpoint when ready
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            selected = Set(viewModel.user?.interests ?? [])
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Photo resize helper

private extension UIImage {
    // Downscales to a max 512pt dimension and re-encodes as JPEG before upload —
    // a profile picture never needs to be full camera resolution, and this keeps
    // uploads fast and radar/chat-list image loads cheap for everyone who sees it.
    func resizedForUpload(maxDimension: CGFloat = 512, quality: CGFloat = 0.75) -> Data? {
        let scale = min(1, maxDimension / max(size.width, size.height))
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
