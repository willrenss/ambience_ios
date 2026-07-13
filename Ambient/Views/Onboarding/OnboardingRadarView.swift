//
//  OnboardingRadarView.swift
//  Ambient
//
//  Created by Laurentius Brandon Vikario on 09/07/26.
//

import SwiftUI

struct OnboardingRadarView: View {
    var onNext: () -> Void = {}
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    Image("Onboarding3")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height * 0.58)
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 60, style: .continuous))
                
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
                        
                        Spacer()
                        
                        Button(action: onNext) {
                            Text("Next")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 28)
                                .frame(height: 54)
                                .background(Color(hex: 0x336F7A))
                                .clipShape(Capsule())
                                .background(
                                    Capsule().fill(Color.black).offset(x: 2, y: 4)
                                )
                        }
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 32)
                .padding(.top, 30) 
            }
            .ignoresSafeArea(.all, edges: .top)
        }
    }
}

#Preview {
    OnboardingRadarView()
}
