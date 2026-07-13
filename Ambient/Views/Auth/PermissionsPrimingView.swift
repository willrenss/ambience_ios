import SwiftUI

// Shown once, right after account creation.
struct PermissionsPrimingView: View {
    @Environment(AppState.self) private var appState
    @State private var step: Int = 0
    private let stepCount = 3
    
    // Theme Colors
    let tealButton = Color(hex: 0x336F7A)
    let orangeColor = Color(red: 1.0, green: 0.27, blue: 0.0)
    let lightGreenHill = Color(red: 0.82, green: 0.93, blue: 0.86) // Warna bukit hijau pastel
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.ignoresSafeArea()
                
                // MARK: - Green Hill Background (Khusus Halaman Welcome)
                if step == 2 {
                    VStack {
                        Spacer()
                        Ellipse()
                            .fill(lightGreenHill)
                            .frame(width: geo.size.width * 1.5, height: geo.size.height * 0.5)
                            .offset(y: geo.size.height * 0.15)
                    }
                    .frame(width: geo.size.width)
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
                
                VStack(spacing: 0) {
                    // MARK: - Top Navigation (Back Button)
                    HStack {
                        Button(action: {
                            if step > 0 { step -= 1 }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.black)
                                .padding(16)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        .opacity(step > 0 ? 1 : 0) // Sembunyikan di halaman pertama
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    
                    if step < 2 {
                        // MARK: - Title (Halaman 1 - 2)
                        Text(title)
                            .font(.system(size: 50, weight: .black, design: .default))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .lineSpacing(-5)
                            .padding(.top, 20)
                        
                        Spacer()
                        
                        // MARK: - Illustration
                        illustration
                            .frame(height: 320)
                            .frame(maxWidth: .infinity)
                        
                        Spacer()
                    } else {
                        // MARK: - Welcome Content (Halaman 3)
                        Spacer()
                        
                        VStack(spacing: 16) {
                            Text("Welcome, \(appState.currentUser?.nickname ?? "")!")
                                .font(.system(size: 36, weight: .heavy, design: .default))
                                .foregroundColor(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            
                            Text("Your profile is set up, your sensors are online, and your radar is ready to scan. Let's find some events happening near you based on your interest.")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color(white: 0.35))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 8)
                        }
                        .padding(.horizontal, 28)
                        
                        Spacer()
                    }
                    
                    // MARK: - Actions
                    actions
                        .padding(.horizontal, 28)
                        .padding(.bottom, 24)
                }
                // Kunci juga lebar konten utamanya
                .frame(width: geo.size.width)
            }
            // Pastikan ZStack keseluruhan tidak melebihi lebar layar
            .frame(width: geo.size.width)
            .animation(.easeInOut(duration: 0.3), value: step)
        }
    }
    
    // MARK: - Step Content
    
    private var title: String {
        switch step {
        case 0: return "Enable\nLocation\nAccess"
        case 1: return "Enable\nBluetooth\nAccess"
        default: return "Stay\nNotified"
        }
    }
    
    @ViewBuilder
    private var illustration: some View {
        GeometryReader { geo in
            ZStack {
                switch step {
                case 0:
                    ZStack(alignment: .top) {
                        Image("EnableLocationAccess")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height * 0.58)
                    }
                    
                case 1:
                    // Bluetooth Illustration
                    BluetoothWaveShape()
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.2, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 18, lineCap: .round)
                        )
                        .padding(.horizontal, -20)
                    
                default:
                    // Notifications Illustration
                    ZStack {
                        Circle().fill(Color(red: 1.0, green: 0.9, blue: 0.8)).frame(width: 200)
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 84))
                            .foregroundStyle(orangeColor)
                    }
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 16) {
            switch step {
            case 0:
                Button(action: {
                    Task {
                        await LocationService.shared.requestPermissionAndStart()
                        advance()
                    }
                }) {
                    Text("Allow Location")
                        .primaryButtonStyle(bg: tealButton)
                }
                
            case 1:
                Button(action: {
                    BluetoothPermissionPrimer.shared.request()
                    advance()
                }) {
                    Text("Allow Bluetooth")
                        .primaryButtonStyle(bg: tealButton)
                }
                
                Button(action: { advance() }) {
                    Text("Maybe Later")
                        .secondaryButtonStyle(color: tealButton)
                }
                
            default:
                Button(action: { finish() }) {
                    Text("Let's Explore Map")
                        .primaryButtonStyle(bg: tealButton)
                }
            }
        }
    }
    
    // MARK: - Logic Helpers
    private func advance() {
        if step < stepCount - 1 {
            step += 1
        } else {
            finish()
        }
    }
    
    private func finish() {
        appState.hasSeenPermissionsPriming = true
    }
}



struct BluetoothWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        
        p.move(to: CGPoint(x: 0, y: h * 0.55))
        p.addCurve(to: CGPoint(x: w, y: h * 0.45),
                   control1: CGPoint(x: w * 0.35, y: h * 0.1),
                   control2: CGPoint(x: w * 0.65, y: h * 0.9))
        return p
    }
}

extension View {
    func primaryButtonStyle(bg: Color) -> some View {
        self.font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(bg)
            .clipShape(Capsule())
            .background(
                Capsule().fill(Color.black).offset(x: 0, y: 5)
            )
    }

    func secondaryButtonStyle(color: Color) -> some View {
        self.font(.system(size: 18, weight: .bold))
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(color, lineWidth: 1)
            )
    }
}

#Preview {
    PermissionsPrimingView()
        .environment(AppState())
}
