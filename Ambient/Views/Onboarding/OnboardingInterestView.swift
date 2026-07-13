//
//  OnboardingInterestView.swift
//  Ambient
//
//  Created by Laurentius Brandon Vikario on 09/07/26.
//

import SwiftUI

struct OnboardingInterestView: View {
    var onNext: () -> Void = {}
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    Image("Onboarding1")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height * 0.58)
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 60, style: .continuous))
                
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
                    
                    Button(action: onNext) {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color(hex: 0x336F7A))
                            .clipShape(Capsule())
                            .background(
                                Capsule()
                                    .fill(Color.black)
                                    .offset(x: 0, y: 5)
                            )
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
    OnboardingInterestView()
}
