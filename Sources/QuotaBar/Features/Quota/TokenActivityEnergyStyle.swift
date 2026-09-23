import Foundation
import CodexQuotaCore

/// Maps real token activity to rendering intensity without coupling it to quota burn-rate rules.
extension TokenActivityLevel {
    /// Sets the number of quiet, fixed-lane streaks for each activity tier.
    var streakCount: Int {
        switch self {
        case .calm: return 0
        case .active: return 4
        case .fast: return 7
        case .veryFast: return 10
        }
    }

    var cometCount: Int {
        switch self {
        case .calm: return 0
        case .active: return 1
        case .fast: return 3
        case .veryFast: return 4
        }
    }

    var energyRibbonCount: Int {
        switch self {
        case .calm: return 0
        case .active: return 1
        case .fast, .veryFast: return 2
        }
    }

    var streamLength: Double {
        switch self {
        case .calm: return 0
        case .active: return 82
        case .fast: return 108
        case .veryFast: return 136
        }
    }

    var streamCoreOpacity: Double {
        switch self {
        case .calm: return 0
        case .active: return 0.28
        case .fast: return 0.42
        case .veryFast: return 0.55
        }
    }

    var streamGlowOpacity: Double {
        switch self {
        case .calm: return 0
        case .active: return 0.15
        case .fast: return 0.22
        case .veryFast: return 0.30
        }
    }

    var streamCoreWidth: Double {
        switch self {
        case .calm: return 0
        case .active: return 1.5
        case .fast: return 2.0
        case .veryFast: return 2.4
        }
    }

    var streamGlowWidth: Double {
        switch self {
        case .calm: return 0
        case .active: return 6
        case .fast: return 8
        case .veryFast: return 10
        }
    }

    var streamBlurRadius: Double {
        switch self {
        case .calm: return 0
        case .active: return 6
        case .fast: return 8
        case .veryFast: return 10
        }
    }

    var cometTrailLength: Double {
        switch self {
        case .calm: return 0
        case .active: return 10
        case .fast: return 26
        case .veryFast: return 40
        }
    }

    var cometCoreDiameter: Double {
        switch self {
        case .calm: return 0
        case .active: return 2.8
        case .fast: return 3.2
        case .veryFast: return 3.8
        }
    }

    /// Counts the complete moving set while calm remains completely static.
    var particleCount: Int { streakCount + cometCount }

    var animationFrameInterval: TimeInterval? {
        switch self {
        case .calm: return nil
        case .active: return 1.0 / 12.0
        case .fast: return 1.0 / 18.0
        case .veryFast: return 1.0 / 24.0
        }
    }

    var particleTravelSeconds: Double {
        switch self {
        case .calm: return 0
        case .active: return 5.2
        case .fast: return 2.8
        case .veryFast: return 1.7
        }
    }

    var particleOpacityMultiplier: Double {
        switch self {
        case .calm: return 0.68
        case .active: return 0.90
        case .fast: return 1.05
        case .veryFast: return 1.20
        }
    }
}
