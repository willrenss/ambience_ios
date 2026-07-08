import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: OnboardingViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                ZStack {
                    stepContent(vm)
                        .id(vm.step)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                }
                .animation(.easeInOut(duration: 0.30), value: vm.step)
            } else {
                Color.white.ignoresSafeArea().overlay { ProgressView() }
            }
        }
        .onAppear {
            if viewModel == nil { viewModel = OnboardingViewModel(appState: appState) }
        }
        .task { await viewModel?.loadInterests() }
    }

    @ViewBuilder
    private func stepContent(_ vm: OnboardingViewModel) -> some View {
        switch vm.step {
        case 0: NameStep(vm: vm)
        case 1: AgeStep(vm: vm)
        case 2: HometownStep(vm: vm)
        default: InterestsStep(vm: vm)
        }
    }
}

// MARK: - Shared: Progress + Next Button

private struct OnboardingBottomBar: View {
    let step: Int
    let isLoading: Bool
    let canContinue: Bool
    let isLast: Bool
    let safeBottom: CGFloat
    let onNext: () -> Void

    private let teal = Color(hex: 0x1E7082)
    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 14) {
            // Two-part progress bar
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: 0xF2A099).opacity(0.45))
                    .frame(height: 7)
                GeometryReader { g in
                    Capsule()
                        .fill(teal)
                        .frame(width: g.size.width * CGFloat(step + 1) / CGFloat(totalSteps), height: 7)
                }
                .frame(height: 7)
            }
            .animation(.easeInOut(duration: 0.25), value: step)

            // Next button — same 3D shadow approach as WalkthroughView
            Button {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
                onNext()
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Text(isLast ? "Create Account" : "Next")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background {
                GeometryReader { g in
                    ZStack(alignment: .topLeading) {
                        // Black shadow layer offset bottom-right
                        RoundedRectangle(cornerRadius: 27)
                            .fill(.black)
                            .frame(width: g.size.width, height: g.size.height)
                            .offset(x: 4, y: 6)
                        // Teal surface
                        RoundedRectangle(cornerRadius: 27)
                            .fill(teal)
                            .frame(width: g.size.width, height: g.size.height)
                    }
                }
            }
            .padding(.bottom, 7)
            .padding(.trailing, 5)
            .disabled(isLoading)
            .opacity(canContinue ? 1 : 0.60)
        }
        .padding(.bottom, max(safeBottom, 24))
    }
}

// MARK: - Step 0: Name

private let randomNicknames: [String] = [
    "Misty Fox", "Lunar Cat", "Neon Bird", "Cosmic Bear", "Solar Wolf",
    "Echo Hawk", "Storm Fish", "Blaze Deer", "Chill Panda", "Nova Lynx",
    "Pixel Owl", "Turbo Bee", "Velvet Elk", "Crimson Jay", "Shadow Moth"
]

private struct NameStep: View {
    @Bindable var vm: OnboardingViewModel
    @FocusState private var focused: Bool
    // Captured once before keyboard appears — prevents title from shifting
    @State private var fixedHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let imgH = fixedHeight * 0.65

            VStack(spacing: 0) {
                // ── Image card (rounded bottom corners) ──────────────────────
                ZStack(alignment: .bottomLeading) {
                    Image("Welcome1")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: imgH)
                        .clipped()

                    // Subtle gradient so text is readable
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.20), location: 0.0),
                            .init(color: .black.opacity(0.55), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )

                    // Content overlay inside image
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: geo.safeAreaInsets.top + 12)

                        Spacer(minLength: imgH * 0.27)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("WELCOME!")
                                .font(.system(size: 64, weight: .heavy))
                                .foregroundStyle(Color.scale(.brand, 600))
                            Text("LETS GET\nTO IT!")
                                .font(.system(size: 64, weight: .heavy))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: 12)

                        // Form at the bottom of the image
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Enter your name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)

                            TextField("enter your nickname...", text: $vm.nickname)
                                .font(.system(size: 16))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule().stroke(Color.white.opacity(0.55), lineWidth: 1.5)
                                )
                                .background(Color.white.opacity(0.08), in: Capsule())
                                .foregroundStyle(.white)
                                .tint(.white)
                                .focused($focused)
                                .onAppear { focused = true }
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)

                            Button {
                                vm.nickname = randomNicknames.randomElement() ?? "Nova Lynx"
                            } label: {
                                Text("Pick a Random")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 10)
                                    .background(Color.black.opacity(0.40), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: imgH)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0, bottomLeadingRadius: 32,
                        bottomTrailingRadius: 32, topTrailingRadius: 0
                    )
                )
                .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)

                // ── White bottom section ─────────────────────────────────────
                VStack(spacing: 0) {
                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.errorRed)
                            .padding(.top, 12)
                            .padding(.horizontal, 28)
                    }
                    Spacer(minLength: 16)
                    OnboardingBottomBar(
                        step: 0, isLoading: vm.isLoading,
                        canContinue: vm.canContinueCurrentStep,
                        isLast: false, safeBottom: geo.safeAreaInsets.bottom,
                        onNext: { Task { await vm.advance() } }
                    )
                    .padding(.horizontal, 28)
                }
                .frame(maxWidth: .infinity)
                .background(.white)
            }
            .onAppear {
                if fixedHeight == 0 { fixedHeight = geo.size.height }
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(.white)
    }
}

// MARK: - Step 1: Age

private struct OnboardingAgeGroup {
    let generation: String
    let letter: String
    let ageRange: String   // e.g. "14-35"
    let midAge: Int

    // "Gen Z" → "Gen", "Millennial" → "Millennial"
    var displayPrefix: String {
        generation.components(separatedBy: " ").first ?? generation
    }
}

private let allAgeGroups: [OnboardingAgeGroup] = [
    .init(generation: "Gen Alpha", letter: "α", ageRange: "13-16", midAge: 14),
    .init(generation: "Gen Z",     letter: "Z", ageRange: "14-29", midAge: 22),
    .init(generation: "Millennial",letter: "M", ageRange: "30-45", midAge: 37),
    .init(generation: "Gen X",     letter: "X", ageRange: "46-61", midAge: 53),
    .init(generation: "Boomer",    letter: "B", ageRange: "62-80", midAge: 71),
]

private struct AgeStep: View {
    @Bindable var vm: OnboardingViewModel
    @State private var selectedIndex: Int = 1
    @State private var scrollAnchor: Int? = 1

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                Button { vm.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(20)
                }

                Text("How Old\nAre You?")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)

                Spacer()

                let cardWidth = geo.size.width * 0.62
                let cardHeight = cardWidth * 1.35  // 200×270 Figma asset ratio
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(allAgeGroups.indices, id: \.self) { i in
                            AgeCard(group: allAgeGroups[i], isSelected: i == selectedIndex)
                                .frame(width: cardWidth, height: cardHeight)
                                .id(i)
                                .onTapGesture {
                                    withAnimation(.spring(duration: 0.3)) {
                                        selectedIndex = i
                                        scrollAnchor = i
                                    }
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .safeAreaPadding(.horizontal, (geo.size.width - cardWidth) / 2)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $scrollAnchor)
                .frame(height: cardHeight + 20)
                .onChange(of: scrollAnchor) { _, pos in
                    if let pos {
                        selectedIndex = pos
                        vm.ageText = String(allAgeGroups[pos].midAge)
                    }
                }
                .onAppear {
                    vm.ageText = String(allAgeGroups[selectedIndex].midAge)
                }

                Spacer()

                if let error = vm.errorMessage {
                    Text(error).font(.caption).foregroundStyle(Color.errorRed)
                        .padding(.horizontal, 28)
                }

                OnboardingBottomBar(
                    step: 1, isLoading: vm.isLoading,
                    canContinue: vm.canContinueCurrentStep,
                    isLast: false, safeBottom: geo.safeAreaInsets.bottom,
                    onNext: { Task { await vm.advance() } }
                )
                .padding(.horizontal, 28)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(.white)
    }
}

private struct AgeCard: View {
    let group: OnboardingAgeGroup
    let isSelected: Bool

    // Darker orange for the big decorative letter background
    private let letterColor = Color(hex: 0xB83808)

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card background
            if isSelected {
                Image("ageBackground")
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray5))
            }

            // Large decorative letter — clipped inside the card
            Text(group.letter)
                .font(.system(size: 150, weight: .heavy))
                .foregroundStyle(
                    isSelected
                        ? letterColor.opacity(0.50)
                        : Color(.systemGray3).opacity(0.55)
                )
                .offset(x: 14, y: 28)

            // Content pinned top-leading and bottom-leading
            VStack(alignment: .leading, spacing: 0) {
                // Generation prefix: "Gen", "Millennial", etc.
                Text(group.displayPrefix)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(isSelected ? .white : Color(.systemGray2))
                    .padding(.top, 20)
                    .padding(.horizontal, 20)

                Spacer()

                // Age range split: number on one line, label on the next
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.ageRange)
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundStyle(isSelected ? .white : Color(.systemGray3))
                    Text("YEARS OLD")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isSelected ? .white : Color(.systemGray3))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        // Clip the overflowing large letter to the card bounds
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .scaleEffect(isSelected ? 1 : 0.91)
        .animation(.spring(duration: 0.3), value: isSelected)
    }
}

// MARK: - Step 2: Hometown

private struct HometownStep: View {
    @Bindable var vm: OnboardingViewModel
    @FocusState private var focused: Bool

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                // Back button
                Button { vm.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(20)
                }

                // Title — centered
                Text("Where Are\nYou From?")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)

                // Field sits just below title — Spacer below keeps BottomBar pinned
                TextField("enter your hometown...", text: $vm.hometown, axis: .vertical)
                    .font(.system(size: 16))
                    .lineLimit(1...3)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20).stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .focused($focused)
                    .onSubmit { focused = false }
                    .submitLabel(.done)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 28)
                    .padding(.top, 32)
                    .onChange(of: vm.hometown) { _, new in
                        if new.contains("\n") {
                            vm.hometown = new.replacingOccurrences(of: "\n", with: "")
                            focused = false
                        }
                    }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.errorRed)
                        .padding(.horizontal, 28)
                        .padding(.top, 8)
                }

                // Spacer only compresses when keyboard appears — field stays visible
                Spacer(minLength: 16)

                OnboardingBottomBar(
                    step: 2, isLoading: vm.isLoading,
                    canContinue: vm.canContinueCurrentStep,
                    isLast: false, safeBottom: geo.safeAreaInsets.bottom,
                    onNext: { Task { await vm.advance() } }
                )
                .padding(.horizontal, 28)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(.white)
    }
}

// MARK: - Step 3: Interests

private struct InterestsStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                Button { vm.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(20)
                }

                VStack(alignment: .center, spacing: 6) {
                    Text("What are your interests ?")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                    Text("Pick at least 3 activities you are currently into")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .padding(.bottom, 20)

                ScrollView {
                    FlowLayout(spacing: 10) {
                        ForEach(vm.filteredInterests) { interest in
                            OnboardingInterestChip(
                                interest: interest,
                                isSelected: vm.selectedInterestIDs.contains(interest.id),
                                onToggle: { vm.toggle(interest) }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }

                if let error = vm.errorMessage {
                    Text(error).font(.caption).foregroundStyle(Color.errorRed)
                        .padding(.horizontal, 28)
                }

                OnboardingBottomBar(
                    step: 3, isLoading: vm.isLoading,
                    canContinue: vm.canContinueCurrentStep,
                    isLast: true, safeBottom: geo.safeAreaInsets.bottom,
                    onNext: { Task { await vm.advance() } }
                )
                .padding(.horizontal, 28)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(.white)
    }
}

private struct OnboardingInterestChip: View {
    let interest: Interest
    let isSelected: Bool
    let onToggle: () -> Void

    private let chipTeal     = Color(hex: 0x2B7880)
    private let chipSelected = Color(hex: 0x1E6070)

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? Color(hex: 0x4A9BAC) : chipTeal.opacity(0.70))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(String(interest.name.prefix(1)).uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )

                Text(interest.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Image(systemName: isSelected ? "checkmark" : "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.leading, 4)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(isSelected ? chipSelected : chipTeal, in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: isSelected)
    }
}
