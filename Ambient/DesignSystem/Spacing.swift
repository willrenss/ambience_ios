import CoreGraphics

// 8pt grid per Apple HIG — reference these constants instead of magic numbers.
enum Spacing {
    static let xs: CGFloat = 4    // very tight (between interest tags)
    static let sm: CGFloat = 8    // within small components (icon to label)
    static let md: CGFloat = 12   // padding inside small cards
    static let lg: CGFloat = 16   // standard horizontal screen padding, card gaps
    static let xl: CGFloat = 20   // vertical section padding
    static let xxl: CGFloat = 24  // between large sections
    static let xxxl: CGFloat = 32 // top/bottom screen margin
}

// Card corner radius (spec: 20–24pt).
enum Radius {
    static let card: CGFloat = 22
    static let chip: CGFloat = 14
}
