import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationRouter.self) private var router
    @State private var viewModel: ProfileViewModel?
    @State private var notificationsEnabled: Bool = false
    @State private var serverURL: String = ServerConfig.currentURL

    var body: some View {
        List {
            if let user = viewModel?.user {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 56, height: 56)
                            Text(String(user.displayName.prefix(1)).uppercased())
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundStyle(.tint)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName)
                                .font(.headline)
                            Text("Member")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            Section("Preferences") {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
            }

            Section {
                HStack {
                    Text("Server URL")
                        .foregroundStyle(.secondary)
                    TextField("http://192.168.x.x:8080", text: $serverURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Developer")
            } footer: {
                Text("On device: set to your Mac's local IP. Tap elsewhere to save.")
                    .font(.caption)
            }

            Section("Accessibility") {
                NavigationLink {
                    BackTapSetupView()
                } label: {
                    Label("Set up Back Tap", systemImage: "hand.tap")
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { await viewModel?.signOut() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel?.isLoading == true {
                            ProgressView()
                        } else {
                            Text("Sign Out")
                                .bold()
                        }
                        Spacer()
                    }
                }
                .disabled(viewModel?.isLoading == true)
            }
        }
        .navigationTitle("Profile")
        .onAppear {
            if viewModel == nil {
                viewModel = ProfileViewModel(appState: appState)
            }
            notificationsEnabled = UserDefaults.standard.bool(forKey: "notifications_enabled")
        }
        .onChange(of: notificationsEnabled) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "notifications_enabled")
        }
        .onChange(of: serverURL) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, URL(string: trimmed) != nil else { return }
            ServerConfig.setURL(trimmed)
        }
    }
}
