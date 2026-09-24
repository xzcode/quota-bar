import Foundation
import CodexQuotaCore

/// Maps local token activity to dense-particle counts and timing without changing activity thresholds.
extension TokenActivityLevel {
    var rightVioletAccent: Double {
        switch self {
        case .calm: return 0
        case .slow: return 0.05
        case .medium: return 0.10
        case .fast: return 0.18
        case .veryFast: return 0.28
        }
    }

    var particleCount: Int {
        switch self {
        case .calm: return 0
        case .slow: return 32
        case .medium: return 64
        case .fast: return 96
        case .veryFast: return 128
        }
    }

    var brightParticleCount: Int {
        switch self {
        case .calm: return 0
        case .slow: return 4
        case .medium: return 8
        case .fast: return 12
        case .veryFast: return 16
        }
    }

    var sparkleParticleCount: Int {
        switch self {
        case .calm: return 0
        case .slow: return 1
        case .medium: return 2
        case .fast: return 5
        case .veryFast: return 9
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
        case .slow: return 4.5
        case .medium: return 3.2
        case .fast: return 2.2
        case .veryFast: return 0.7
        }
    }
}
