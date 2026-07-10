//
//  OnboardingInterestView.swift
//  Ambient
//
//  Created by Laurentius Brandon Vikario on 09/07/26.
//

import SwiftUI

struct OnboardingInterestView: View {
    // Tambahkan action closure
    var onNext: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                HeaderBackground()
                VStack(alignment: .leading, spacing: -5) {
                    Text("Your\nJourney\nStarts")
                        .font(.system(size: 64, weight: .heavy, design: .default))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 4)
                    
                    Text("Now!")
                        .font(.system(size: 64, weight: .heavy, design: .default))
                        .foregroundColor(Color(red: 0.82, green: 0.22, blue: 0.05))
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.bottom, 150)
            }
            .frame(height: UIScreen.main.bounds.height * 0.58)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Tell us about your interest!")
                    .font(.system(size: 34, weight: .black, design: .default))
                    .foregroundColor(Color.black)
                    .lineSpacing(4)
                
                Text("This helps us customize your map and ensure you discover events and people that truly match your vibe.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color.gray)
                    .lineSpacing(2)
                    .padding(.trailing, 16)
                
                Spacer()
                
                // Gunakan action onNext di sini
                Button(action: onNext) {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(red: 0.22, green: 0.44, blue: 0.47))
                        .clipShape(Capsule())
                        .background(
                            Capsule()
                                .fill(Color.black)
                                .offset(x: 0, y: 5)
                        )
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 32)
            .padding(.top, 30)
        }
        .ignoresSafeArea(.all, edges: .top)
    }
}

// MARK: - Header Components (Tetap sama seperti aslinya)
struct HeaderBackground: View {
    var body: some View {
        ZStack {
            Color(red: 1.0, green: 0.27, blue: 0.0)
            WaveShape().fill(Color(red: 0.85, green: 0.20, blue: 0.0).opacity(0.5)).offset(y: -80)
            WaveShape2().fill(Color(red: 0.9, green: 0.22, blue: 0.0).opacity(0.3)).offset(x: 80, y: 120)
            Group {
                PillView().rotationEffect(.degrees(-5)).offset(x: -160, y: 205)
                PillView().rotationEffect(.degrees(-5)).offset(x: -110, y: 240)
                PillView().rotationEffect(.degrees(-10)).offset(x: -35, y: 200)
                PillView().rotationEffect(.degrees(-5)).offset(x: -10, y: 238)
                PillView().rotationEffect(.degrees(30)).offset(x: 50, y: 190)
                PillView().rotationEffect(.degrees(-5)).offset(x: 80, y: 242)
                PillView().rotationEffect(.degrees(-5)).offset(x: 150, y: 200)
            }
        }
        .cornerRadius(60)
    }
}

struct PillView: View {
    var body: some View {
        Capsule()
            .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
            .frame(width: 90, height: 38)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
    }
}

struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY * 0.3))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.1), control1: CGPoint(x: rect.maxX * 0.4, y: rect.maxY * 0.6), control2: CGPoint(x: rect.maxX * 0.8, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 0))
        return path
    }
}

struct WaveShape2: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY * 0.7))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.3), control1: CGPoint(x: rect.maxX * 0.5, y: rect.maxY * 1.2), control2: CGPoint(x: rect.maxX * 0.8, y: rect.maxY * 0.1))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 0))
        return path
    }
}

#Preview {
    OnboardingInterestView()
}
