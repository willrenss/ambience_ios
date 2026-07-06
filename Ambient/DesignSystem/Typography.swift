import SwiftUI

// SF Pro (system font) type scale — same size/weight hierarchy as the
// previous Plus Jakarta Sans scale, but uses the built-in system font.
extension Font {
    // MARK: Display
    static let display2XLarge: Font = .system(size: 57, weight: .bold)
    static let displayXLarge: Font  = .system(size: 48, weight: .bold)
    static let displayLarge: Font   = .system(size: 40, weight: .bold)
    static let displayMedium: Font  = .system(size: 33, weight: .bold)
    static let displaySmall: Font   = .system(size: 28, weight: .bold)

    // MARK: Headline
    static let headlineLarge: Font  = .system(size: 25, weight: .semibold)
    static let headlineMedium: Font = .system(size: 24, weight: .semibold)
    static let headlineSmall: Font  = .system(size: 21, weight: .semibold)

    // MARK: Title
    static let titleLarge: Font  = .system(size: 19, weight: .semibold)
    static let titleMedium: Font = .system(size: 18, weight: .semibold)
    static let titleSmall: Font  = .system(size: 18, weight: .semibold)

    // MARK: Body
    static let bodyLarge: Font  = .system(size: 17, weight: .regular)
    static let bodyMedium: Font = .system(size: 16, weight: .regular)
    static let bodySmall: Font  = .system(size: 15, weight: .regular)

    // MARK: Label
    static let labelLarge: Font  = .system(size: 15, weight: .medium)
    static let labelMedium: Font = .system(size: 14, weight: .medium)
    static let labelSmall: Font  = .system(size: 13, weight: .medium)
}
