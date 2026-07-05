import SwiftUI

// Plus Jakarta Sans type scale per the "Typography System — Style Guide
// Generator" reference. Font.custom's `relativeTo:` variant is used instead
// of a bare fixed size — this keeps the guide's exact base point sizes while
// still letting the system's Larger Text accessibility setting scale
// everything proportionally, rather than fully abandoning Dynamic Type.
//
// Weight mapping (the guide only calls out SemiBold as a named sample, not a
// full per-style weight table, so this is a deliberate, defensible choice):
// Display = Bold, Headline/Title = SemiBold, Body = Regular, Label = Medium.
extension Font {
    private static func jakarta(_ weight: JakartaWeight, _ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(weight.postScriptName, size: size, relativeTo: style)
    }

    // MARK: Display — hero sections, main headlines (Bold)
    static let display2XLarge = jakarta(.bold, 57, relativeTo: .largeTitle)
    static let displayXLarge  = jakarta(.bold, 48, relativeTo: .largeTitle)
    static let displayLarge   = jakarta(.bold, 40, relativeTo: .largeTitle)
    static let displayMedium  = jakarta(.bold, 33, relativeTo: .title)
    static let displaySmall   = jakarta(.bold, 28, relativeTo: .title)

    // MARK: Headline — important section headers (SemiBold)
    static let headlineLarge  = jakarta(.semiBold, 25, relativeTo: .title2)
    static let headlineMedium = jakarta(.semiBold, 24, relativeTo: .title2)
    static let headlineSmall  = jakarta(.semiBold, 21, relativeTo: .title3)

    // MARK: Title — content titles and subsection headers (SemiBold)
    static let titleLarge  = jakarta(.semiBold, 19, relativeTo: .headline)
    static let titleMedium = jakarta(.semiBold, 18, relativeTo: .headline)
    static let titleSmall  = jakarta(.semiBold, 18, relativeTo: .headline)

    // MARK: Body — main content and paragraph text (Regular)
    static let bodyLarge  = jakarta(.regular, 17, relativeTo: .body)
    static let bodyMedium = jakarta(.regular, 16, relativeTo: .body)
    static let bodySmall  = jakarta(.regular, 15, relativeTo: .subheadline)

    // MARK: Label — button text, fields, supporting UI (Medium)
    static let labelLarge  = jakarta(.medium, 15, relativeTo: .subheadline)
    static let labelMedium = jakarta(.medium, 14, relativeTo: .footnote)
    static let labelSmall  = jakarta(.medium, 13, relativeTo: .caption)
}

private enum JakartaWeight {
    case regular, medium, semiBold, bold

    var postScriptName: String {
        switch self {
        case .regular:  return "PlusJakartaSans-Regular"
        case .medium:   return "PlusJakartaSans-Medium"
        case .semiBold: return "PlusJakartaSans-SemiBold"
        case .bold:     return "PlusJakartaSans-Bold"
        }
    }
}
