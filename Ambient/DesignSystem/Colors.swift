import SwiftUI

// Nowi warm/soft palette + semantic colors from the product spec.
// Hex values are the single source of truth; use these instead of ad-hoc Color(...).
extension Color {
    // Primary palette
    static let coral      = Color(hex: 0xFF7D6B)  // primary action
    static let apricot    = Color(hex: 0xFFC49A)  // secondary accent
    static let honey      = Color(hex: 0xFFD27F)  // tertiary accent, badge/tag
    static let peach      = Color(hex: 0xFFDCC7)  // soft background, card fill
    static let terracotta = Color(hex: 0xE07A5F)  // dark accent, text/icon on light

    // Semantic
    static let successGreen = Color(hex: 0x7FBF9F)
    static let infoBlue     = Color(hex: 0x7EB6E6)
    static let warningAmber = Color(hex: 0xFFC46B)
    static let errorRed     = Color(hex: 0xFF8D8D)

    static var overlayDim: Color { Color.black.opacity(0.4) }

    // "Radar not connected yet" state — deliberately muted/desaturated so it
    // reads as offline, contrasting with the warm palette once radar is live.
    static let slate      = Color(hex: 0x7C8794)
    static let slateLight = Color(hex: 0x9BA5B0)

    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
