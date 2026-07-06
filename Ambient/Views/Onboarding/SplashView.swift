import SwiftUI

struct SplashView: View {
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
