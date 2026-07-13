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

// MARK: - Shared: Progress + Next Button

private struct OnboardingBottomBar: View {
    let step: Int
    let isLoading: Bool
    let canContinue: Bool
    let isLast: Bool
    let onNext: () -> Void

    private let teal = Color(hex: 0x336F7A)

    var body: some View {
        VStack(spacing: 14) {
            // Bagian "Two-part progress bar" (ZStack) sudah dihapus dari sini
            
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
                            .foregroundStyle(.white)
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
        .padding(.bottom, 24)
    }
}

// MARK: - Step 0: Name

private let randomNicknames: [String] = [
    "Misty Fox", "Lunar Cat", "Neon Bird", "Cosmic Bear", "Solar Wolf",
    "Echo Hawk", "Storm Fish", "Blaze Deer", "Chill Panda", "Nova Lynx",
    "Pixel Owl", "Turbo Bee", "Velvet Elk", "Crimson Jay", "Shadow Moth"
]

// MARK: - Step 0: Name

// MARK: - Step 0: Name

private struct NameStep: View {
    @Bindable var vm: OnboardingViewModel
    @FocusState private var focused: Bool
    
    // Theme Colors
    let bgOrange = Color(red: 1.0, green: 0.27, blue: 0.0)
    let darkOrange = Color(red: 0.82, green: 0.18, blue: 0.0) // For "Lets" and bottom hill
    let inputBg = Color(red: 0.96, green: 0.55, blue: 0.41) // Coral/Peach for textfield
    let tealButton = Color(hex: 0x336F7A)
    
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
                    .frame(maxWidth: .infinity, minHeight: 350, maxHeight: 350)
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
                
                ZStack(alignment: .bottom) {
                    Image("NameCard")
                        .resizable()
                        .scaledToFit() // <--- Ubah modifier ini dari .scaledToFill() menjadi .scaledToFit()
                }
                
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
                            Text("Continue")
                        }
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
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
        .onTapGesture { focused = false }
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

// Not private — ProfileView's Age Group picker reuses this data/AgeCard so the
// two pickers (onboarding and later edits) never drift apart.
struct OnboardingAgeGroup {
    let generation: String
    let letter: String
    let ageRange: String
    let midAge: Int

    let background: Color
    let accent: Color
    let letterColor: Color

    var displayPrefix: String {
        generation.components(separatedBy: " ").first ?? generation
    }
}

extension OnboardingAgeGroup {
    static func closest(toAge age: Int) -> OnboardingAgeGroup {
        allAgeGroups.min { abs($0.midAge - age) < abs($1.midAge - age) } ?? allAgeGroups[0]
    }
}

let allAgeGroups: [OnboardingAgeGroup] = [

    // Gen Alpha (Ungu)
    .init(
        generation: "Gen Alpha",
        letter: "α",
        ageRange: "2-15",
        midAge: 14,
        background: Color(hex: 0x7A63D6),
        accent: Color(hex: 0x8F79E9),
        letterColor: Color(hex: 0x52428F)   // <-- Hue sama dengan background, brightness diturunkan
    ),

    // Gen Z (Merah Orange)
    .init(
        generation: "Gen Z",
        letter: "Z",
        ageRange: "14-29",
        midAge: 22,
        background: Color(hex: 0xFF4D14),
        accent: Color(hex: 0xFF6535),
        letterColor: Color(hex: 0xB53A11)   // <-- Referensi (sudah benar)
    ),

    // Gen Y (Hijau)
    .init(
        generation: "Gen Y",
        letter: "Y",
        ageRange: "30-45",
        midAge: 37,
        background: Color(hex: 0x71D39A),
        accent: Color(hex: 0x8AE4AF),
        letterColor: Color(hex: 0x488B65)   // <-- Hue sama dengan background, brightness diturunkan
    ),

    // Gen X (Coklat)
    .init(
        generation: "Gen X",
        letter: "X",
        ageRange: "46-61",
        midAge: 53,
        background: Color(hex: 0xD8A16C),
        accent: Color(hex: 0xE8BD8B),
        letterColor: Color(hex: 0x936D49)   // <-- Hue sama dengan background, brightness diturunkan
    )
]

private struct AgeStep: View {
    @Bindable var vm: OnboardingViewModel
    @State private var selectedIndex: Int = 1
    @State private var scrollAnchor: Int? = nil

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
                    scrollAnchor = selectedIndex
                }

                Spacer()

                if let error = vm.errorMessage {
                    Text(error).font(.caption).foregroundStyle(Color.errorRed)
                        .padding(.horizontal, 28)
                }

                OnboardingBottomBar(
                    step: 1, isLoading: vm.isLoading,
                    canContinue: vm.canContinueCurrentStep,
                    isLast: false,
                    onNext: { Task { await vm.advance() } }
                )
                .padding(.horizontal, 28)
            }
        }
        .background(Color.white.ignoresSafeArea())
    }
}

struct AgeCard: View {
    let group: OnboardingAgeGroup
    let isSelected: Bool
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(group.background.opacity(isSelected ? 1 : 0.55))

            Text(group.letter)
                .font(.system(size: 150, weight: .heavy))
                .foregroundStyle(group.letterColor.opacity(isSelected ? 0.50 : 0.30))
                .offset(x: 14, y: 28)

            VStack(alignment: .leading, spacing: 0) {
                Text(group.displayPrefix)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.8))
                    .padding(.top, 20)
                    .padding(.horizontal, 20)

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.ageRange)
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundStyle(.white.opacity(isSelected ? 1 : 0.8))
                    Text("YEARS OLD")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(isSelected ? 1 : 0.8))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .scaleEffect(isSelected ? 1 : 0.91)
        .animation(.spring(duration: 0.3), value: isSelected)
    }
}

// MARK: - Step 2: Hometown

private struct HometownStep: View {
    @Bindable var vm: OnboardingViewModel
    @FocusState private var focused: Bool
    
    // Theme colors matching mockup
    let bgOffWhite = Color(hex: 0xF7F8FA) // Very light gray/white background
    let tealButton = Color(hex: 0x336F7A) // Button color
    let orangeText = Color(red: 1.0, green: 0.27, blue: 0.0) // "Grow Up" color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                bgOffWhite
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    // Back button
                    Button { vm.goBack() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.black)
                            .padding(16)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.leading, 24)
                            .padding(.top, 10)
                    }

                    // Complex title typography
                    VStack(alignment: .leading, spacing: -5) {
                        Text("Where Did")
                            .font(.system(size: 58, weight: .black, design: .default))
                            .foregroundColor(.black)
                        
                        HStack(spacing: 0) {
                            Text("You ")
                                .font(.system(size: 58, weight: .black, design: .default))
                                .foregroundColor(.black)
                            Text("Grow")
                                .font(.system(size: 58, weight: .black, design: .default))
                                .foregroundColor(orangeText)
                        }
                        
                        HStack(spacing: 8) {
                            Text("Up")
                                .font(.system(size: 58, weight: .black, design: .default))
                                .foregroundColor(orangeText)
                            Text("?")
                                .font(.system(size: 58, weight: .black, design: .default))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    
                    Spacer()
                        .frame(height: 60)
                    
                    // Subtitle text
                    Text("Let us know your hometown")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(Color(white: 0.2))
                        .padding(.horizontal, 28)
                        .padding(.bottom, 16)

                    // Outlined TextField
                    TextField("Enter your city or hometown", text: $vm.hometown)
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.black, lineWidth: 1)
                        )
                        .focused($focused)
                        .onSubmit { focused = false }
                        .submitLabel(.done)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .padding(.horizontal, 28)

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.errorRed)
                            .padding(.horizontal, 28)
                            .padding(.top, 8)
                    }
                    
                    Spacer()

                    // Custom Continue Button (Neu-brutalism style to match design)
                    Button(action: {
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
                                Text("Continue")
                            }
                        }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
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
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }
            }
            .onTapGesture { focused = false }
        }
    }
}

// MARK: - Hometown Illustration Components

struct PerspectiveJakartaCard: View {
    let label: String
    var withTower: Bool = false
    let rotation: Double
    var scale: CGFloat = 1.0
    
    let purple = Color(hex: 0x9083CF) // Adjusted to a slightly softer purple
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(purple)
                // Added a subtle white border and stronger shadow for depth
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.3), lineWidth: 1))
                .shadow(color: .black.opacity(0.2), radius: 8, x: -4, y: 8)
            
            VStack(spacing: 0) {
                if withTower {
                    TowerShape()
                        .fill(Color.white.opacity(0.3)) // Semi-transparent tower silhouette
                        .frame(width: 45, height: 75)
                        .padding(.bottom, 8)
                }
                Text(label)
                    .font(.system(size: 26, weight: .heavy, design: .default))
                    .foregroundColor(.white)
            }
        }
        // Adjusted base dimensions to make it look more like a wide card before rotation
        .frame(width: 140, height: 180)
        // Aggressive 3D rotation to make it lie flat on the "ground"
        .rotation3DEffect(.degrees(55), axis: (x: 1.0, y: 0.0, z: 0.0))
        .scaleEffect(scale)
        .rotationEffect(.degrees(rotation))
    }
}

struct TowerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        
        // Simplified Monas-like silhouette
        path.move(to: CGPoint(x: c.x - 8, y: rect.minY)) // Top flame base
        path.addLine(to: CGPoint(x: c.x + 8, y: rect.minY))
        path.addLine(to: CGPoint(x: c.x + 12, y: c.y - 15)) // Flare out
        path.addLine(to: CGPoint(x: c.x + 16, y: rect.maxY - 20)) // Base top
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)) // Base bottom right
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)) // Base bottom left
        path.addLine(to: CGPoint(x: c.x - 16, y: rect.maxY - 20)) // Base top left
        path.addLine(to: CGPoint(x: c.x - 12, y: c.y - 15))
        path.addLine(to: CGPoint(x: c.x - 8, y: rect.minY))
        return path
    }
}

//#Preview {
//    NameStep(
//        vm: OnboardingViewModel(appState: AppState())
//    )
//}

#Preview {
    AgeStep(
        vm: OnboardingViewModel(appState: AppState())
    )
}

//#Preview {
//    HometownStep(
//        vm: OnboardingViewModel(appState: AppState())
//    )
//}

//#Preview {
//    InterestsStep(
//        vm: OnboardingViewModel(appState: AppState())
//    )
//}

// MARK: - Step 3: Interests

private struct InterestsStep: View {
    @Bindable var vm: OnboardingViewModel
    @FocusState private var searchFocused: Bool

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
                .padding(.bottom, 12)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    TextField("Search interests...", text: $vm.searchText)
                        .font(.system(size: 15))
                        .focused($searchFocused)
                        .autocorrectionDisabled()
                    if !vm.searchText.isEmpty {
                        Button { vm.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

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
                .scrollDismissesKeyboard(.interactively)

                if let error = vm.errorMessage {
                    Text(error).font(.caption).foregroundStyle(Color.errorRed)
                        .padding(.horizontal, 28)
                }

                OnboardingBottomBar(
                    step: 3, isLoading: vm.isLoading,
                    canContinue: vm.canContinueCurrentStep,
                    isLast: true,
                    onNext: { Task { await vm.advance() } }
                )
                .padding(.horizontal, 28)
            }
            .onTapGesture { searchFocused = false }
        }
        .background(Color.white.ignoresSafeArea())
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



