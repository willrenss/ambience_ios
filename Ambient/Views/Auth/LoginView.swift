import SwiftUI

<<<<<<< HEAD
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
=======
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: OnboardingViewModel?
    @State private var serverURL: String = ServerConfig.currentURL
    @State private var showServerConfig = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            Color.peach.opacity(0.35).ignoresSafeArea()

            if let vm = viewModel {
                content(vm)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = OnboardingViewModel(appState: appState)
            }
            serverURL = ServerConfig.currentURL
        }
        .task {
            await viewModel?.loadInterests()
        }
    }

    @ViewBuilder
    private func content(_ vm: OnboardingViewModel) -> some View {
        @Bindable var vm = vm
        VStack(spacing: 0) {
            header(vm)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    switch vm.step {
                    case 0: nicknameStep(vm)
                    case 1: ageStep(vm)
                    case 2: hometownStep(vm)
                    default: interestsStep(vm)
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Color.errorRed)
                    }

                    if vm.step == 0 { serverConfig }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.xxxl)
            }

            continueButton(vm)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
        }
        .onChange(of: vm.step) { _, _ in fieldFocused = true }
    }

    // MARK: - Header (back chevron + progress bar + skip)

    private func header(_ vm: OnboardingViewModel) -> some View {
        HStack(spacing: Spacing.md) {
            Button {
                vm.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(Color.terracotta)
            }
            .opacity(vm.step > 0 ? 1 : 0)
            .disabled(vm.step == 0)

            ZStack(alignment: .leading) {
                Capsule().fill(Color.apricot.opacity(0.4)).frame(height: 6)
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.coral)
                        .frame(width: geo.size.width * CGFloat(vm.step + 1) / 4, height: 6)
                }
                .frame(height: 6)
            }
            .frame(height: 6)
            .animation(.easeInOut(duration: 0.25), value: vm.step)

            Button("Skip") {
                Task { await vm.advance() }
            }
            .font(.labelLarge)
            .foregroundStyle(Color.terracotta)
            .opacity(vm.step == 3 ? 1 : 0)
            .disabled(vm.step != 3)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    // MARK: - Steps

    private func stepTitle(_ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Let's start now!")
                .font(.headlineSmall)
                .foregroundStyle(Color.terracotta)
            Text(subtitle)
                .font(.bodyMedium)
                .foregroundStyle(.secondary)
        }
    }

    private func nicknameStep(_ vm: OnboardingViewModel) -> some View {
        @Bindable var vm = vm
        return VStack(alignment: .leading, spacing: Spacing.xxl) {
            stepTitle("Enter a nickname you're comfy with")
            TextField("Nickname...", text: $vm.nickname)
                .font(.displaySmall)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .focused($fieldFocused)
                .onAppear { fieldFocused = true }
        }
    }

    private func ageStep(_ vm: OnboardingViewModel) -> some View {
        @Bindable var vm = vm
        return VStack(alignment: .leading, spacing: Spacing.xxl) {
            stepTitle("Enter your age")
            TextField("Age...", text: $vm.ageText)
                .font(.displaySmall)
                .keyboardType(.numberPad)
                .focused($fieldFocused)
        }
    }

    private func hometownStep(_ vm: OnboardingViewModel) -> some View {
        @Bindable var vm = vm
        return VStack(alignment: .leading, spacing: Spacing.xxl) {
            stepTitle("Enter your Hometown")
            TextField("Hometown...", text: $vm.hometown)
                .font(.displaySmall)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .focused($fieldFocused)
        }
    }

    private func interestsStep(_ vm: OnboardingViewModel) -> some View {
        @Bindable var vm = vm
        return VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                (Text("Let's pick your ") + Text("Interests").foregroundStyle(Color.coral))
                    .font(.headlineSmall)
                    .foregroundStyle(Color.terracotta)
                Text("Proud foodie or fancy on football? Add interests to your profile to help you match with the events which relate to.")
                    .font(.bodyMedium)
                    .foregroundStyle(.secondary)
            }

            TextField("Search", text: $vm.searchText)
                .font(.bodyMedium)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: Radius.chip))
                .focused($fieldFocused)

            Text("You might like...")
                .font(.titleSmall)
                .foregroundStyle(Color.terracotta)

            FlowLayout(spacing: Spacing.sm) {
                ForEach(vm.filteredInterests) { interest in
                    Button {
                        vm.toggle(interest)
                    } label: {
                        InterestChip(title: interest.name,
                                     selected: vm.selectedInterestIDs.contains(interest.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func continueButton(_ vm: OnboardingViewModel) -> some View {
        Button {
            Task { await vm.advance() }
        } label: {
            if vm.isLoading {
                ProgressView().tint(.white)
            } else {
                Text(vm.step == 3 ? "Create Account" : "Continue")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!vm.canContinueCurrentStep || vm.isLoading)
        .opacity(vm.canContinueCurrentStep ? 1 : 0.5)
    }

    private var serverConfig: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
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
                        Task { await viewModel?.loadInterests() }
                    }
                    .font(.caption.bold())
                }
            }
        }
        .padding(.top, Spacing.sm)
>>>>>>> c5f4022 (Iniatial Commit)
    }
}
