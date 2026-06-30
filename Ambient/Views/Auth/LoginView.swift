import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: LoginViewModel?
    @State private var serverURL: String = ServerConfig.currentURL
    @State private var showServerConfig = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(.tint)

                    Text("Ambient Social")
                        .font(.largeTitle.bold())

                    Text("Discover people nearby at your favorite third places")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                if let vm = viewModel {
                    VStack(spacing: 16) {
                        TextField("Your name", text: Bindable(vm).name)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .padding(.horizontal, 32)

                        if vm.isLoading {
                            ProgressView()
                                .frame(height: 50)
                        } else {
                            Button {
                                Task { await vm.login() }
                            } label: {
                                Text("Continue")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.horizontal, 32)
                            .disabled(vm.name.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        if let error = vm.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                }

                // Server config — tap to expand
                VStack(spacing: 8) {
                    Button {
                        withAnimation { showServerConfig.toggle() }
                    } label: {
                        Label(showServerConfig ? "Hide server config" : "Server: \(serverURL)",
                              systemImage: "server.rack")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if showServerConfig {
                        HStack {
                            TextField("http://192.168.x.x:8080", text: $serverURL)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .font(.caption)
                            Button("Save") {
                                ServerConfig.setURL(serverURL)
                                showServerConfig = false
                            }
                            .font(.caption.bold())
                        }
                        .padding(.horizontal, 32)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            viewModel = LoginViewModel(appState: appState)
            serverURL = ServerConfig.currentURL
        }
    }
}
