import Foundation

/// A persisted usage observation for one bucket/window pair.
public struct QuotaUsageSample: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let bucketId: String
    public let windowKind: QuotaWindow.WindowKind
    public let usedPercent: Int

    public init(timestamp: Date, bucketId: String, windowKind: QuotaWindow.WindowKind, usedPercent: Int) {
        self.timestamp = timestamp
        self.bucketId = bucketId
        self.windowKind = windowKind
        self.usedPercent = usedPercent
    }
}

/// Four deliberately broad levels keep animation changes stable between polls.
public enum BurnRateLevel: String, Codable, Equatable, Sendable {
    case calm
    case active
    case fast
    case veryFast

    public var label: String {
        switch self {
        case .calm: return "平稳"
        case .active: return "活跃"
        case .fast: return "较快"
        case .veryFast: return "很快"
        }
    }

    /// Only animated states render the subdued background flow particles.
    public var backgroundParticleCount: Int {
        switch self {
        case .calm: return 0
        case .active: return 6
        case .fast: return 8
        case .veryFast: return 9
        }
    }

    /// Limits bright moving particles to one or two per frame.
    public var energyParticleCount: Int {
        switch self {
        case .calm: return 0
        case .active: return 1
        case .fast, .veryFast: return 2
        }
    }

    /// Short trails are reserved for the two highest activity levels.
    public var trailCount: Int {
        switch self {
        case .calm, .active: return 0
        case .fast: return 2
        case .veryFast: return 3
        }
    }

    /// Limits the ribbon layer to two concurrent strands at most.
    public var energyRibbonCount: Int {
        switch self {
        case .calm: return 0
        case .active: return 1
        case .fast, .veryFast: return 2
        }
    }

    /// Lengthens the comet fade only for the faster animation tiers.
    public var cometTrailLength: Double {
        switch self {
        case .calm, .active: return 0
        case .fast: return 7
        case .veryFast: return 12
        }
    }

    /// Moving highlight stays subtle at active burn and broadens slightly at higher rates.
    public var movingHighlightWidth: Double {
        switch self {
        case .calm: return 0
        case .active: return 22
        case .fast: return 30
        case .veryFast: return 36
        }
    }

    /// Visual intensity for the shared moving highlight and ribbon layer.
    public var movingHighlightOpacity: Double {
        switch self {
        case .calm: return 0
        case .active: return 0.12
        case .fast: return 0.19
        case .veryFast: return 0.25
        }
    }

    /// Includes static dots, energy particles, and trail marks.
    public var particleCount: Int {
        backgroundParticleCount + energyParticleCount + trailCount
    }

    /// Returns nil for calm so the compact UI can avoid creating a TimelineView.
    public var animationFrameInterval: TimeInterval? {
        switch self {
        case .calm: return nil
        case .active: return 1.0 / 12.0
        case .fast: return 1.0 / 18.0
        case .veryFast: return 1.0 / 24.0
        }
    }

    /// Approximate seconds for a particle to cross the compact bar.
    public var particleTravelSeconds: Double {
        switch self {
        case .calm: return 0
        case .active: return 6.5
        case .fast: return 4
        case .veryFast: return 2.4
        }
    }

    /// Small gradient movement multiplier; it is independent of danger color.
    public var gradientSpeed: Double {
        switch self {
        case .calm: return 0
        case .active: return 0.08
        case .fast: return 0.14
        case .veryFast: return 0.22
        }
    }

    /// Burn rate changes highlight strength without changing danger colors.
    public var particleOpacityMultiplier: Double {
        switch self {
        case .calm: return 0.68
        case .active: return 0.90
        case .fast: return 1.05
        case .veryFast: return 1.20
        }
    }
}

/// The current burn-rate result. A nil rate means there are not enough
/// trustworthy samples yet; the visual level intentionally falls back to calm.
public struct BurnRateSnapshot: Codable, Equatable, Sendable {
    public let percentPerMinute: Double?
    public let level: BurnRateLevel

    public init(percentPerMinute: Double?, level: BurnRateLevel) {
        self.percentPerMinute = percentPerMinute
        self.level = level
    }

    public static let unknown = BurnRateSnapshot(percentPerMinute: nil, level: .calm)
}

/// Calculates a smoothed rate from at most the latest ten minutes of samples.
public enum BurnRateCalculator {
    public static let lookback: TimeInterval = 10 * 60

    public static func calculate(
        samples: [QuotaUsageSample],
        now: Date = .now,
        lookback: TimeInterval = BurnRateCalculator.lookback
    ) -> BurnRateSnapshot {
        let cutoff = now.addingTimeInterval(-lookback)
        let recent = samples
            .filter { $0.timestamp >= cutoff && $0.timestamp <= now }
            .sorted { $0.timestamp < $1.timestamp }

        guard let first = recent.first, let last = recent.last, first.timestamp < last.timestamp else {
            return .unknown
        }

        let elapsedMinutes = last.timestamp.timeIntervalSince(first.timestamp) / 60
        guard elapsedMinutes >= 1 else { return .unknown }

        let delta = last.usedPercent - first.usedPercent
        // A decrease is handled as a reset by the history store. Returning an
        // unknown result here prevents a reset from looking like negative burn.
        guard delta >= 0 else { return .unknown }

        let rate = Double(delta) / elapsedMinutes
        return BurnRateSnapshot(percentPerMinute: rate, level: level(for: rate))
    }

    public static func level(for rate: Double?) -> BurnRateLevel {
        guard let rate else { return .calm }
        switch rate {
        case ..<0.05: return .calm
        case ..<0.15: return .active
        case ..<0.35: return .fast
        default: return .veryFast
        }
    }
}
