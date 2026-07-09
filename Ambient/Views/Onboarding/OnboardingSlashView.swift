//
//  OnboardingSlashView.swift
//  Ambient
//
//  Created by Laurentius Brandon Vikario on 09/07/26.
//

import SwiftUI

struct OnboardingSplashView: View {
    var body: some View {
        ZStack {
            Color(hex: 0xFAF5EF).ignoresSafeArea()
            Text("NOWI")
                .font(.custom("PlusJakartaSans-Bold", size: 52))
                .foregroundStyle(Color.primary)
                .kerning(6)
        }
    }
}
