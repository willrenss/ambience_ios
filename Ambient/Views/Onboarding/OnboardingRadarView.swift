//
//  OnboardingRadarView.swift
//  Ambient
//
//  Created by Laurentius Brandon Vikario on 09/07/26.
//

import SwiftUI

struct OnboardingRadarView: View {
    // Tambahkan action closures
    var onSkip: () -> Void = {}
    var onNext: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 0) {
            RadarIllustrationView()
                .frame(height: UIScreen.main.bounds.height * 0.58)
                .clipShape(RoundedRectangle(cornerRadius: 60, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 5)
                .ignoresSafeArea(.all, edges: .top)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Unlock Your\nSocial Radar")
                    .font(.system(size: 38, weight: .black, design: .default))
                    .foregroundColor(.black)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Arrive at the venue and activate Social Radar. Discover nearby users and connect instantly.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(white: 0.4))
                    .lineSpacing(4)
                    .padding(.trailing, 8)
                
                Spacer()
                
                HStack {
                    // Gunakan action onSkip
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .background(
                                Capsule().fill(Color.black).offset(x: 2, y: 4)
                            )
                    }
                    
                    Spacer()
                    
                    // Gunakan action onNext
                    Button(action: onNext) {
                        Text("Next")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 16)
                            .background(Color(red: 0.35, green: 0.64, blue: 0.67))
                            .clipShape(Capsule())
                            .background(
                                Capsule().fill(Color.black).offset(x: 2, y: 4)
                            )
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 32)
            .padding(.top, -33)
        }
    }
}

// MARK: - Radar Vector Component (Tetap sama seperti aslinya)
struct RadarIllustrationView: View {
    let orange = Color(red: 1.0, green: 0.34, blue: 0.13)
    private let ringDiameters: [CGFloat] = [1400, 1080, 800, 560, 360, 200]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                orange
                ZStack {
                    ForEach(Array(ringDiameters.enumerated()), id: \.offset) { index, diameter in
                        Circle()
                            .fill(index.isMultiple(of: 2) ? Color.white : orange)
                            .frame(width: diameter, height: diameter)
                    }
                    SpiralTailShape()
                        .fill(Color.white)
                        .frame(width: 1400, height: 1400)
                }
                .scaleEffect(x: 1.25, y: 0.82)
                .rotationEffect(.degrees(-28))
                .position(x: geo.size.width * 0.38, y: geo.size.height * 0.36)
            }
            .clipped()
        }
    }
}

struct SpiralTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let start = CGPoint(x: w * 0.86, y: h * 0.62)
        
        path.move(to: start)
        path.addCurve(to: CGPoint(x: w * 0.52, y: h * 0.985), control1: CGPoint(x: w * 0.92, y: h * 0.80), control2: CGPoint(x: w * 0.74, y: h * 0.97))
        path.addCurve(to: CGPoint(x: w * 0.80, y: h * 0.70), control1: CGPoint(x: w * 0.40, y: h * 0.995), control2: CGPoint(x: w * 0.66, y: h * 0.90))
        path.closeSubpath()
        return path
    }
}

#Preview {
    OnboardingRadarView()
}
