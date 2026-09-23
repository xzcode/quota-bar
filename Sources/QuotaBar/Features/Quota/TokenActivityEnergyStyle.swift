import Foundation
import CodexQuotaCore

/// Maps real token activity to rendering intensity without coupling it to quota burn-rate rules.
extension TokenActivityLevel {
    var backgroundParticleCount: Int {
        switch self {
        case .calm: return 0
        case .active: return 6
        case .fast: return 8
        case .veryFast: return 9
        }
    }

    var energyParticleCount: Int {
        switch self {
        case .calm: return 0
        case .active: return 1
        case .fast, .veryFast: return 2
        }
    }

    var trailCount: Int {
        switch self {
        case .calm, .active: return 0
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

    var cometTrailLength: Double {
        switch self {
        case .calm, .active: return 0
        case .fast: return 7
        case .veryFast: return 12
        }
    }

    var movingHighlightWidth: Double {
        switch self {
        case .calm: return 0
        case .active: return 22
        case .fast: return 30
        case .veryFast: return 36
        }
    }

    var movingHighlightOpacity: Double {
        switch self {
        case .calm: return 0
        case .active: return 0.12
        case .fast: return 0.19
        case .veryFast: return 0.25
        }
    }

    var particleCount: Int { backgroundParticleCount + energyParticleCount + trailCount }

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

    var gradientSpeed: Double {
        switch self {
        case .calm: return 0
        case .active: return 0.08
        case .fast: return 0.14
        case .veryFast: return 0.22
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
