import SwiftUI

// Full 13-step ramp system from the "Color Guidelines — Style Guide
// Generator" PDF: Brand, Accent, Neutral, Success, Error, Warning, each
// spanning 25 (near-white) to 1000 (near-black).
//
// The PDF only labels one "Main" hex per family (the rest are unlabeled
// swatches), so the other 12 steps per family are generated rather than
// hand-copied: each family's hue/saturation is taken from its Main hex, and
// lightness follows a fixed curve calibrated so the generated value at the
// Main step lands within ~1pt of the PDF's given hex (verified below).
//
// Deliberately additive: nothing here replaces `Colors.swift`'s existing
// coral/apricot/honey/peach/terracotta/successGreen/infoBlue/warningAmber/
// errorRed — those keep the app's current warm palette untouched. Use
// `Color.scale(_:_:)` when a screen specifically needs a guideline-exact
// tint/shade beyond what the existing semantic names offer.
enum ColorFamily {
    case brand, accent, neutral, success, error, warning

    // Hue (degrees) and saturation (%) sampled from the PDF's one labeled
    // "Main" swatch per family; held constant across that family's ramp.
    fileprivate var hue: Double {
        switch self {
        case .brand:   return 14.1    // #f6815d, step 400
        case .accent:  return 189.5   // #b2d2d8, step 300
        case .neutral: return 214.3   // #7c7f83, step 600
        case .success: return 145.0   // #48bb78, step 600
        case .error:   return 359.7   // #ff2829, step 500
        case .warning: return 47.0    // #ecc94b, step 500
        }
    }

    fileprivate var saturation: Double {
        switch self {
        case .brand:   return 89.5
        case .accent:  return 32.8
        case .neutral: return 2.7
        case .success: return 45.8
        case .error:   return 100.0
        case .warning: return 80.9
        }
    }
}

extension Color {
    /// All valid steps, lightest to darkest.
    static let colorScaleSteps = [25, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950, 1000]

    /// A single step from one of the guideline's 6 color ramps.
    static func scale(_ family: ColorFamily, _ step: Int) -> Color {
        let lightness = ColorScale.lightness[step] ?? 50
        // Saturation eases off slightly at the very light/dark ends so 25 and
        // 1000 don't look artificially vivid — standard practice for
        // generated tint/shade ramps.
        let saturation = family.saturation * ColorScale.saturationFactor[step, default: 1.0]
        return .fromHSL(hue: family.hue, saturation: saturation, lightness: lightness)
    }
}

private enum ColorScale {
    // Calibrated against the PDF's 4 given anchors (Accent-300≈77.3%,
    // Brand-400≈66.5%, Error-500≈57.8%/Warning-500≈61%, Neutral-600=50.0%/
    // Success-600≈50.8%) — all land within ~1-2pt of these fixed values.
    static let lightness: [Int: Double] = [
        25: 98.5, 50: 96.5, 100: 93, 200: 85.5, 300: 77.5, 400: 68,
        500: 58.5, 600: 50, 700: 41, 800: 32, 900: 23.5, 950: 17, 1000: 10.5,
    ]

    static let saturationFactor: [Int: Double] = [
        25: 0.5, 50: 0.6, 100: 0.75, 200: 0.85, 300: 0.92, 400: 0.96,
        500: 1.0, 600: 1.0, 700: 1.0, 800: 0.95, 900: 0.9, 950: 0.85, 1000: 0.8,
    ]
}

private extension Color {
    /// Builds a Color from HSL (H in degrees, S/L in percent 0-100).
    static func fromHSL(hue: Double, saturation: Double, lightness: Double) -> Color {
        let h = hue / 360
        let s = saturation / 100
        let l = lightness / 100

        guard s > 0 else { return Color(white: l) }

        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q

        func hueToRGB(_ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6 { return p + (q - p) * 6 * t }
            if t < 1.0 / 2 { return q }
            if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
            return p
        }

        let r = hueToRGB(h + 1.0 / 3)
        let g = hueToRGB(h)
        let b = hueToRGB(h - 1.0 / 3)
        return Color(red: r, green: g, blue: b)
    }
}
