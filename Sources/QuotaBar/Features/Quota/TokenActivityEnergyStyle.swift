import Foundation
import CodexQuotaCore

/// Maps local token activity to dense-particle counts and timing without changing activity thresholds.
extension TokenActivityLevel {
    var rightVioletAccent: Double {
        switch self {
        case .calm: return 0
        case .slow: return 0.07
        case .medium: return 0.12
        case .fast: return 0.22
        case .veryFast: return 0.32
        }
    }

    var rightVioletOverlayOpacity: Double {
        switch self {
        case .calm: return 0
        case .slow: return 0.24
        case .medium: return 0.44
        case .fast: return 0.64
        case .veryFast: return 0.80
        }
    }

    var rightVioletParticleTint: Double {
        switch self {
        case .calm: return 0
        case .slow: return 0.04
        case .medium: return 0.08
        case .fast: return 0.13
        case .veryFast: return 0.18
        }
    }

    var farParticleCount: Int {
        switch self {
        case .calm: return 0
        case .slow: return 7
        case .medium: return 9
        case .fast: return 12
        case .veryFast: return 14
        }
    }

    var midParticleCount: Int {
        switch self {
        case .calm: return 0
        case .slow: return 7
        case .medium: return 11
        case .fast: return 14
        case .veryFast: return 19
        }
    }

    var nearParticleCount: Int {
        switch self {
        case .calm: return 0
        case .slow: return 2
        case .medium: return 4
        case .fast: return 5
        case .veryFast: return 7
        }
    }

    var particleCount: Int {
        farParticleCount + midParticleCount + nearParticleCount
    }

    var brightParticleCount: Int {
        switch self {
        case .calm: return 0
        case .slow: return 1
        case .medium: return 2
        case .fast: return 3
        case .veryFast: return 5
        }
    }

    var sparkleParticleCount: Int {
        switch self {
        case .calm: return 0
        case .slow: return 1
        case .medium: return 2
        case .fast: return 3
        case .veryFast: return 5
        }
    }

    var sparkleFrequencyHz: Double {
        switch self {
        case .calm: return 0
        case .slow: return 1.0
        case .medium: return 1.5
        case .fast: return 2.2
        case .veryFast: return 3.0
        }
    }

    var sparkleDepth: Double {
        switch self {
        case .calm: return 0
        case .slow: return 0.14
        case .medium: return 0.20
        case .fast: return 0.26
        case .veryFast: return 0.32
        }
    }

    var softEnergyGlowOpacity: Double {
        switch self {
        case .calm: return 0
        case .slow: return 0.04
        case .medium: return 0.055
        case .fast: return 0.07
        case .veryFast: return 0.085
        }
    }

    var animationFrameInterval: TimeInterval? {
        switch self {
        case .calm: return nil
        case .slow, .medium: return 1.0 / 30.0
        case .fast: return 1.0 / 45.0
        case .veryFast: return 1.0 / 60.0
        }
    }

    var particleTravelSeconds: Double {
        switch self {
        case .calm: return 0
        case .slow: return 4.2
        case .medium: return 3.0
        case .fast: return 2.1
        case .veryFast: return 1.3
        }
    }
}
