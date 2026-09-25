import Foundation
import CodexQuotaCore

/// Identifies the five independently phased, fixed-speed particle streams.
enum ParticleStreamID: Int, CaseIterable {
    case farLane0
    case farLane4
    case midLane1
    case midLane3
    case nearLane2

    var lane: Int {
        switch self {
        case .farLane0: return 0
        case .farLane4: return 4
        case .midLane1: return 1
        case .midLane3: return 3
        case .nearLane2: return 2
        }
    }

    /// Stream velocity is stable for its whole lane; activity only changes the shared base speed.
    var speedMultiplier: Double {
        switch self {
        case .farLane0: return 0.60
        case .farLane4: return 0.64
        case .midLane1: return 1.00
        case .midLane3: return 1.05
        case .nearLane2: return 1.65
        }
    }

    /// Stream counts sum to layer totals 16/10/4, 24/18/6, 34/26/8, and 46/34/10.
    func particleCount(for level: TokenActivityLevel) -> Int {
        switch self {
        case .farLane0, .farLane4:
            switch level {
            case .calm: return 0
            case .slow: return 8
            case .medium: return 12
            case .fast: return 17
            case .veryFast: return 23
            }
        case .midLane1, .midLane3:
            switch level {
            case .calm: return 0
            case .slow: return 5
            case .medium: return 9
            case .fast: return 13
            case .veryFast: return 17
            }
        case .nearLane2:
            switch level {
            case .calm: return 0
            case .slow: return 4
            case .medium: return 6
            case .fast: return 8
            case .veryFast: return 10
            }
        }
    }
}

/// Maps local token activity to particle styling and timing without changing activity thresholds.
extension TokenActivityLevel {
    var rightVioletAccent: Double {
        switch self {
        case .calm: return 0
        case .slow: return 0.12
        case .medium: return 0.19
        case .fast: return 0.28
        case .veryFast: return 0.39
        }
    }

    var rightVioletCoverageStartX: CGFloat {
        switch self {
        case .calm: return 0.82
        case .slow: return 0.78
        case .medium: return 0.72
        case .fast: return 0.63
        case .veryFast: return 0.52
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
        ParticleStreamID.farLane0.particleCount(for: self)
            + ParticleStreamID.farLane4.particleCount(for: self)
    }

    var midParticleCount: Int {
        ParticleStreamID.midLane1.particleCount(for: self)
            + ParticleStreamID.midLane3.particleCount(for: self)
    }

    var nearParticleCount: Int {
        ParticleStreamID.nearLane2.particleCount(for: self)
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
