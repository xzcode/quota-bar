import Foundation
import CodexQuotaCore

/// Maps real token activity to rendering intensity without coupling it to quota burn-rate rules.
extension TokenActivityLevel {
    /// Keeps the total count of sparks and comets below the twelve-item budget.
    var sparkCount: Int {
        switch self {
        case .calm: return 0
        case .active: return 4
        case .fast: return 6
        case .veryFast: return 8
        }
    }

    var cometCount: Int {
        switch self {
        case .calm: return 0
        case .active: return 1
        case .fast: return 2
        case .veryFast: return 3
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
        case .fast: return 22
        case .veryFast: return 36
        }
    }

    var cometCoreDiameter: Double {
        switch self {
        case .calm: return 0
        case .active: return 2.8
        case .fast: return 3.2
        case .veryFast: return 3.6
        }
    }

    var sweepWidth: Double {
        switch self {
        case .calm: return 0
        case .active: return 32
        case .fast: return 42
        case .veryFast: return 52
        }
    }

    var sweepOpacity: Double {
        switch self {
        case .calm: return 0
        case .active: return 0.16
        case .fast: return 0.34
        case .veryFast: return 0.46
        }
    }

    var edgeStreakWidth: Double {
        switch self {
        case .calm, .active: return 0
        case .fast: return 26
        case .veryFast: return 36
        }
    }

    var edgeStreakOpacity: Double {
        switch self {
        case .calm, .active: return 0
        case .fast: return 0.42
        case .veryFast: return 0.58
        }
    }

    var particleCount: Int { sparkCount + cometCount }

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
        case .active: return 6.5
        case .fast: return 4
        case .veryFast: return 2.4
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
