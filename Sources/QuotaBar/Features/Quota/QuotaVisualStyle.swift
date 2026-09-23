import SwiftUI

/// Fixed danger categories used to select the compact bar's base palette.
enum QuotaDangerState: Hashable {
    case normal
    case low
    case critical
    case unknown
}

/// Centralized quota colors keep danger state separate from burn-rate motion.
enum QuotaVisualStyle {
    /// Maps only danger thresholds to a compact palette; normal hue ignores the exact percentage.
    static func dangerState(remaining: Int?) -> QuotaDangerState {
        guard let remaining else { return .unknown }
        if remaining <= 10 { return .critical }
        if remaining <= 25 { return .low }
        return .normal
    }

    /// Returns the calm glass capsule palette for its discrete quota danger state.
    static func palette(for state: QuotaDangerState) -> [Color] {
        switch state {
        case .normal:
            return [rgb(0x2D, 0x5B, 0xFF), rgb(0x4B, 0x45, 0xD6), rgb(0x6B, 0x3E, 0xC7)]
        case .low:
            return [rgb(0x4B, 0x45, 0xD6), rgb(0x6B, 0x3E, 0xC7), rgb(0x87, 0x4B, 0xB5), rgb(0xC0, 0x86, 0x42)]
        case .critical:
            return [rgb(0x2E, 0x0E, 0x54), rgb(0x6A, 0x1B, 0x67), rgb(0xC4, 0x2E, 0x69)]
        case .unknown:
            return [rgb(0x35, 0x40, 0x58), rgb(0x3E, 0x42, 0x5E), rgb(0x4B, 0x42, 0x5D)]
        }
    }

    /// Supplies the subdued particle hues while the capsule base keeps its own danger palette.
    static func softEnergyParticlePalette(for state: QuotaDangerState) -> [Color] {
        switch state {
        case .normal:
            return [rgb(0x55, 0xBF, 0xFF), rgb(0x55, 0x7B, 0xFF), rgb(0x7B, 0x5B, 0xFF)]
        case .low:
            return [rgb(0xA7, 0x72, 0xFF), rgb(0xC3, 0x5D, 0xE8), rgb(0xFF, 0xC3, 0x6A)]
        case .critical:
            return [rgb(0xFF, 0x6A, 0xD8), rgb(0xE5, 0x3D, 0x91), rgb(0xA4, 0x49, 0xFF)]
        case .unknown:
            return [rgb(0x83, 0xC8, 0xE8), rgb(0x78, 0x8B, 0xE8), rgb(0xA0, 0x7B, 0xD8)]
        }
    }

    /// Uses pale tinted cores rather than pure white for the few bright particles.
    static func brightEnergyParticlePalette(for state: QuotaDangerState) -> [Color] {
        switch state {
        case .normal:
            return [rgb(0xC8, 0xF4, 0xFF), rgb(0xD6, 0xE6, 0xFF), rgb(0xE1, 0xD4, 0xFF)]
        case .low:
            return [rgb(0xE5, 0xD9, 0xFF), rgb(0xF4, 0xD7, 0xF3), rgb(0xFF, 0xE8, 0xC7)]
        case .critical:
            return [rgb(0xFF, 0xD9, 0xF1), rgb(0xFF, 0xD1, 0xDF), rgb(0xE8, 0xD8, 0xFF)]
        case .unknown:
            return [rgb(0xD8, 0xEE, 0xFF), rgb(0xD8, 0xDD, 0xFF), rgb(0xE9, 0xD7, 0xFF)]
        }
    }

    /// Keeps expanded progress-row colors independent from the compact capsule redesign.
    private static let paletteStops = [
        PaletteStop(remaining: 0, colors: [
            RGBColor(red: 0.18, green: 0.06, blue: 0.30),
            RGBColor(red: 0.44, green: 0.08, blue: 0.36),
            RGBColor(red: 0.70, green: 0.12, blue: 0.36)
        ]),
        PaletteStop(remaining: 10, colors: [
            RGBColor(red: 0.22, green: 0.06, blue: 0.34),
            RGBColor(red: 0.50, green: 0.11, blue: 0.40),
            RGBColor(red: 0.72, green: 0.12, blue: 0.42)
        ]),
        PaletteStop(remaining: 25, colors: [
            RGBColor(red: 0.28, green: 0.12, blue: 0.58),
            RGBColor(red: 0.72, green: 0.24, blue: 0.58),
            RGBColor(red: 0.84, green: 0.38, blue: 0.22)
        ]),
        PaletteStop(remaining: 100, colors: [
            RGBColor(red: 0.16, green: 0.30, blue: 0.78),
            RGBColor(red: 0.28, green: 0.26, blue: 0.75),
            RGBColor(red: 0.40, green: 0.22, blue: 0.72)
        ])
    ]

    /// Interpolates palette stops continuously so quota changes do not jump at thresholds.
    static func gradientColors(remaining: Double?, isStale: Bool) -> [Color] {
        guard let remaining else {
            let unknown = [Color.gray.opacity(0.55), Color.gray.opacity(0.38)]
            return isStale ? unknown.map { $0.opacity(0.72) } : unknown
        }

        let bounded = max(0, min(100, remaining))
        let lower = paletteStops.last(where: { $0.remaining <= bounded }) ?? paletteStops[0]
        let upper = paletteStops.first(where: { $0.remaining >= bounded }) ?? paletteStops[paletteStops.count - 1]
        let span = upper.remaining - lower.remaining
        let progress = span > 0 ? (bounded - lower.remaining) / span : 0
        let colors = zip(lower.colors, upper.colors).map { start, end in
            start.interpolated(to: end, progress: progress).color
        }
        return isStale ? colors.map { $0.opacity(0.72) } : colors
    }

    static func progressColors(remaining: Int) -> [Color] {
        gradientColors(remaining: Double(remaining), isStale: false)
    }

    /// Converts byte-style RGB values to SwiftUI's normalized color components.
    private static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red / 255, green: green / 255, blue: blue / 255)
    }

    /// One corresponding RGB gradient stop at a quota palette anchor.
    private struct RGBColor {
        let red: Double
        let green: Double
        let blue: Double

        func interpolated(to other: RGBColor, progress: Double) -> RGBColor {
            RGBColor(
                red: red + (other.red - red) * progress,
                green: green + (other.green - green) * progress,
                blue: blue + (other.blue - blue) * progress
            )
        }

        var color: Color {
            Color(red: red, green: green, blue: blue)
        }
    }

    /// Stores same-shaped palettes so each gradient stop can be interpolated safely.
    private struct PaletteStop {
        let remaining: Double
        let colors: [RGBColor]
    }
}
