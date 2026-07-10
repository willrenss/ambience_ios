//
//  OnboardingExploreSocialEventView.swift
//  Ambient
//
//  Created by Laurentius Brandon Vikario on 09/07/26.
//

import SwiftUI

struct OnboardingExploreSocialEventView: View {
    // Tambahkan action closures
    var onSkip: () -> Void = {}
    var onNext: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 0) {
            MapIllustrationView()
                .frame(height: UIScreen.main.bounds.height * 0.58)
                .clipShape(RoundedRectangle(cornerRadius: 60, style: .continuous))
                .ignoresSafeArea(.all, edges: .top)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Explore Social\nEvent")
                    .font(.system(size: 38, weight: .black, design: .default))
                    .foregroundColor(.black)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Browse nearby events, gatherings, and festivals from live social updates. Discover what's happening and join the fun.")
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

// MARK: - Vector Illustration Components (Tetap sama seperti aslinya)
struct MapIllustrationView: View {
    let mapBg = Color(red: 0.87, green: 0.87, blue: 0.87)
    let landOrange = Color(red: 1.0, green: 0.27, blue: 0.0)
    let pinDark = Color(red: 0.67, green: 0.16, blue: 0.0)
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                mapBg
                Group {
                    Path { path in
                        path.move(to: .zero)
                        path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * -0.15))
                        path.addCurve(to: CGPoint(x: 0, y: geo.size.height * 0.35), control1: CGPoint(x: geo.size.width * 0.7, y: geo.size.height * 0.5), control2: CGPoint(x: geo.size.width * 0.3, y: geo.size.height * 0.45))
                        path.closeSubpath()
                    }.fill(landOrange)
                    
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geo.size.height * 0.55))
                        path.addCurve(to: CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.6), control1: CGPoint(x: geo.size.width * 0.3, y: geo.size.height * 0.55), control2: CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.57))
                        path.addCurve(to: CGPoint(x: 0, y: geo.size.height * 0.7), control1: CGPoint(x: geo.size.width * 0.4, y: geo.size.height * 0.75), control2: CGPoint(x: geo.size.width * 0.1, y: geo.size.height * 0.7))
                        path.closeSubpath()
                    }.fill(landOrange)
                    
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geo.size.height * 0.75))
                        path.addCurve(to: CGPoint(x: geo.size.width * 0.1, y: geo.size.height), control1: CGPoint(x: geo.size.width * 0.3, y: geo.size.height * 0.75), control2: CGPoint(x: geo.size.width * 0.4, y: geo.size.height * 0.75))
                        path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                        path.closeSubpath()
                    }.fill(landOrange)
                    
                    Path { path in
                        path.move(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.45))
                        path.addCurve(to: CGPoint(x: geo.size.width * 0.65, y: geo.size.height), control1: CGPoint(x: geo.size.width * 0.85, y: geo.size.height * 0.7), control2: CGPoint(x: geo.size.width * 0.8, y: geo.size.height * 0.8))
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        path.closeSubpath()
                    }.fill(landOrange)
                }
                
                Group {
                    Rectangle().fill(Color.white).frame(width: 8, height: 60).rotationEffect(.degrees(35)).position(x: geo.size.width * 0.9, y: geo.size.height * 0.3)
                    Rectangle().fill(Color.white).frame(width: 14, height: 100).rotationEffect(.degrees(35)).position(x: geo.size.width * 0.65, y: geo.size.height * 0.6)
                    Rectangle().fill(Color.white).frame(width: 25, height: 180).rotationEffect(.degrees(35)).position(x: geo.size.width * 0.35, y: geo.size.height * 0.95)
                }
                
                Group {
                    LocationPinView(color: pinDark).frame(width: 15, height: 45).rotationEffect(.degrees(-10)).position(x: geo.size.width * 0.08, y: geo.size.height * 0.28)
                    LocationPinView(color: pinDark).frame(width: 20, height: 60).rotationEffect(.degrees(5)).position(x: geo.size.width * 0.7, y: geo.size.height * 0.1)
                    LocationPinView(color: pinDark).frame(width: 35, height: 80).position(x: geo.size.width * 0.22, y: geo.size.height * 0.5)
                    LocationPinView(color: pinDark).frame(width: 50, height: 110).position(x: geo.size.width * 0.85, y: geo.size.height * 0.85)
                }
            }
        }
    }
}

struct LocationPinView: View {
    var color: Color
    var body: some View {
        VStack(spacing: -10) {
            GeometryReader { geo in
                Path { path in
                    let width = geo.size.width
                    let height = geo.size.height
                    path.move(to: CGPoint(x: width / 2, y: height))
                    path.addCurve(to: CGPoint(x: 0, y: height * 0.3), control1: CGPoint(x: width * 0.3, y: height * 0.7), control2: CGPoint(x: 0, y: height * 0.5))
                    path.addArc(center: CGPoint(x: width / 2, y: height * 0.3), radius: width / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                    path.addCurve(to: CGPoint(x: width / 2, y: height), control1: CGPoint(x: width, y: height * 0.5), control2: CGPoint(x: width * 0.7, y: height * 0.7))
                }.fill(color)
            }
            Ellipse().fill(color.opacity(0.8)).frame(width: 25, height: 8).offset(y: 5)
        }
    }
}

#Preview {
    OnboardingExploreSocialEventView()
}
