//
//  OnboardingSlashView.swift
//  Ambient
//
//  Created by Laurentius Brandon Vikario on 09/07/26.
//

import SwiftUI

struct OnboardingSplashView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.839, green: 0.196, blue: 0.0)
                    .ignoresSafeArea()
                Image("splashscreen")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width * 0.55)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}
