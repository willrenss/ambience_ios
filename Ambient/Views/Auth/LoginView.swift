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

// MARK: - Step 0: Name

private struct NameStep: View {
    @Bindable var vm: OnboardingViewModel
    @FocusState private var focused: Bool
    
    // Theme Colors
    let bgOrange = Color(red: 1.0, green: 0.27, blue: 0.0)
    let darkOrange = Color(red: 0.82, green: 0.18, blue: 0.0) // For "Lets" and bottom hill
    let inputBg = Color(red: 0.96, green: 0.55, blue: 0.41) // Coral/Peach for textfield
    let tealButton = Color(red: 0.22, green: 0.44, blue: 0.47)
    
    var body: some View {
        ZStack {
            // MARK: - Backgrounds
            bgOrange
                .ignoresSafeArea()
            
            // Bottom Dark Curve (Hill Shape)
            VStack {
                Spacer()
                Ellipse()
                    .fill(darkOrange)
                    .frame(width: UIScreen.main.bounds.width * 1, height: 350)
                    .offset(y: 150)
            }
            .ignoresSafeArea()
            
            // MARK: - Main Content
            VStack(alignment: .leading, spacing: 0) {
                
                // Typography Section
                VStack(alignment: .leading, spacing: -5) {
                    Text("Lets")
                        .font(.system(size: 54, weight: .black, design: .default))
                        .foregroundColor(darkOrange)
                    
                    Text("Get to\nKnow Each\nOther!")
                        .font(.system(size: 54, weight: .black, design: .default))
                        .foregroundColor(.white)
                        .lineSpacing(0)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 40)
                
                Spacer()
                    .frame(height: 40)
                
                // Input Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("What should we call you ?")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Custom TextField
                    ZStack(alignment: .leading) {
                        if vm.nickname.isEmpty {
                            Text("enter your nickname...")
                                .foregroundColor(Color.black.opacity(0.5))
                                .padding(.horizontal, 24)
                        }
                        
                        TextField("", text: $vm.nickname)
                            .font(.system(size: 18))
                            .foregroundColor(.black)
                            .padding(.vertical, 18)
                            .padding(.horizontal, 24)
                            .focused($focused)
                            .onAppear { focused = true }
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                    }
                    .background(inputBg)
                    .clipShape(Capsule())
                    
                    // Error Message Logic
                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                    }
                }
                
                Spacer()
                
                // Illustration Section
                NameCardsIllustration()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                
                Spacer()
                
                // Button Section
                Button(action: {
                    // Logic to dismiss keyboard and advance
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                    Task { await vm.advance() }
                }) {
                    Group {
                        if vm.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Get Started")
                        }
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(tealButton)
                    .clipShape(Capsule())
                    .background(
                        Capsule()
                            .fill(Color.black)
                            .offset(x: 0, y: 5)
                    )
                }
                .disabled(vm.isLoading || !vm.canContinueCurrentStep)
                .opacity(vm.canContinueCurrentStep ? 1 : 0.6)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Illustration Components
struct NameCardsIllustration: View {
    var body: some View {
        ZStack {
            // Wavy White String
            WavyStringShape()
                .stroke(Color.white, lineWidth: 4)
            
            // Letter Cards
            Group {
                LetterCard(letter: "N", bgColor: Color(red: 0.85, green: 0.85, blue: 0.85), fgColor: Color(white: 0.65), rotation: -15)
                    .offset(x: -105, y: 15)
                LetterCard(letter: "A", bgColor: Color(red: 0.93, green: 0.78, blue: 0.13), fgColor: Color(red: 0.82, green: 0.65, blue: 0.05), rotation: 5)
                    .offset(x: -30, y: 30)
                LetterCard(letter: "E", bgColor: Color(red: 0.22, green: 0.73, blue: 0.45), fgColor: Color(red: 0.12, green: 0.58, blue: 0.32), rotation: 10)
                    .offset(x: 95, y: 25)
                LetterCard(letter: "M", bgColor: Color(red: 0.35, green: 0.42, blue: 0.95), fgColor: Color(red: 0.28, green: 0.33, blue: 0.85), rotation: -8)
                    .offset(x: 35, y: 5)
            }
            
            // Dark Dots
            Group {
                Circle().fill(Color(white: 0.3)).frame(width: 14).offset(x: -110, y: -30)
                Circle().fill(Color(white: 0.3)).frame(width: 14).offset(x: -35, y: -18)
                Circle().fill(Color(white: 0.3)).frame(width: 14).offset(x: 25, y: -45)
                Circle().fill(Color(white: 0.3)).frame(width: 14).offset(x: 90, y: -28)
            }
        }
    }
}

struct LetterCard: View {
    let letter: String
    let bgColor: Color
    let fgColor: Color
    let rotation: Double
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(bgColor)
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
            Text(letter)
                .font(.system(size: 65, weight: .black, design: .default))
                .foregroundColor(fgColor)
        }
        .frame(width: 75, height: 100)
        .rotationEffect(.degrees(rotation))
    }
}

struct WavyStringShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        
        let start = CGPoint(x: 0, y: c.y - 10)
        let dotN = CGPoint(x: c.x - 110, y: c.y - 30)
        let dotA = CGPoint(x: c.x - 35, y: c.y - 18)
        let dotM = CGPoint(x: c.x + 25, y: c.y - 45)
        let dotE = CGPoint(x: c.x + 90, y: c.y - 28)
        let end = CGPoint(x: rect.maxX, y: c.y - 5)
        
        path.move(to: start)
        path.addQuadCurve(to: dotN, control: CGPoint(x: c.x - 160, y: c.y - 45))
        path.addQuadCurve(to: dotA, control: CGPoint(x: c.x - 70, y: c.y))
        path.addQuadCurve(to: dotM, control: CGPoint(x: c.x - 5, y: c.y - 60))
        path.addQuadCurve(to: dotE, control: CGPoint(x: c.x + 60, y: c.y - 10))
        path.addQuadCurve(to: end, control: CGPoint(x: c.x + 140, y: c.y - 40))
        return path
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
