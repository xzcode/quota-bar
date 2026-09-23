import SwiftUI

/// Centralized quota colors keep danger state separate from burn-rate motion.
enum QuotaVisualStyle {
    static func gradientColors(remaining: Int?, isStale: Bool) -> [Color] {
        let colors: [Color]
        switch remaining {
        case let value? where value <= 10:
            colors = [Color(red: 0.22, green: 0.06, blue: 0.34), Color(red: 0.72, green: 0.12, blue: 0.42)]
        case let value? where value <= 25:
            colors = [Color(red: 0.28, green: 0.12, blue: 0.58), Color(red: 0.72, green: 0.24, blue: 0.58), Color(red: 0.84, green: 0.38, blue: 0.22)]
        case .some:
            colors = [Color(red: 0.16, green: 0.30, blue: 0.78), Color(red: 0.40, green: 0.22, blue: 0.72)]
        case .none:
            colors = [Color.gray.opacity(0.55), Color.gray.opacity(0.38)]
        }

        return isStale ? colors.map { $0.opacity(0.72) } : colors
    }

    static func progressColors(remaining: Int) -> [Color] {
        gradientColors(remaining: remaining, isStale: false)
    }
}
