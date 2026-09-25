import Foundation
import CodexQuotaCore

/// Identifies one independently phased, fixed-speed stream for each active depth/lane pair.
enum ParticleStreamID: Int, CaseIterable {
    case farLane0
    case farLane1
    case farLane2
    case farLane3
    case farLane4
    case midLane1
    case midLane2
    case midLane3
    case midLane4
    case nearLane1
    case nearLane2
    case nearLane3

    var lane: Int {
        switch self {
        case .farLane0: return 0
        case .farLane1, .midLane1, .nearLane1: return 1
        case .farLane2, .midLane2, .nearLane2: return 2
        case .farLane3, .midLane3, .nearLane3: return 3
        case .farLane4, .midLane4: return 4
        }
    }

    var depthLayer: ParticleDepthLayer {
        switch self {
        case .farLane0, .farLane1, .farLane2, .farLane3, .farLane4: return .far
        case .midLane1, .midLane2, .midLane3, .midLane4: return .mid
        case .nearLane1, .nearLane2, .nearLane3: return .near
        }
    }

    /// Stream velocity is stable for its whole lane; activity only changes the shared base speed.
    var speedMultiplier: Double {
        switch self {
        case .farLane0: return 0.60
        case .farLane1, .farLane3: return 0.62
        case .farLane2: return 0.64
        case .farLane4: return 0.60
        case .midLane1: return 1.00
        case .midLane2: return 1.02
        case .midLane3: return 1.05
        case .midLane4: return 1.03
        case .nearLane1, .nearLane3: return 1.55
        case .nearLane2: return 1.65
        }
    }

    /// Independent lane counts sum to the density targets defined for each depth layer.
    func particleCount(for level: TokenActivityLevel) -> Int {
        switch self {
        case .farLane0, .farLane1:
            switch level {
            case .calm: return 0
            case .slow: return 4
            case .medium: return 6
            case .fast: return 8
            case .veryFast: return 11
            }
        case .farLane2:
            switch level {
            case .calm: return 0
            case .slow: return 4
            case .medium: return 6
            case .fast: return 8
            case .veryFast: return 10
            }
        case .farLane3, .farLane4:
            switch level {
            case .calm: return 0
            case .slow: return 3
            case .medium: return 5
            case .fast: return 8
            case .veryFast: return 11
            }
        case .midLane1, .midLane2, .midLane3, .midLane4:
            switch level {
            case .calm: return 0
            case .slow: return 3
            case .medium: return 5
            case .fast: return 7
            case .veryFast: return 9
            }
        case .nearLane1, .nearLane3:
            switch level {
            case .calm: return 0
            case .slow: return 1
            case .medium: return 2
            case .fast: return 3
            case .veryFast: return 3
            }
        case .nearLane2:
            switch level {
            case .calm: return 0
            case .slow: return 3
            case .medium: return 3
            case .fast: return 4
            case .veryFast: return 8
            }
        }
    }

    /// Allocates near bright cores across lanes in a center-weighted 1:2:1 balance.
    func brightParticleCount(for level: TokenActivityLevel) -> Int {
        switch self {
        case .nearLane1:
            switch level {
            case .calm, .slow: return 0
            case .medium, .fast, .veryFast: return 1
            }
        case .nearLane2:
            switch level {
            case .calm: return 0
            case .slow, .medium, .fast: return 1
            case .veryFast: return 3
            }
        case .nearLane3:
            switch level {
            case .calm, .slow, .medium: return 0
            case .fast, .veryFast: return 1
            }
        default:
            return 0
        }
    }

    /// Places the rare largest highlights on both near side lanes once those streams are active.
    func highlightParticleCount(for level: TokenActivityLevel) -> Int {
        switch self {
        case .nearLane1:
            switch level {
            case .calm, .slow: return 0
            case .medium, .fast, .veryFast: return 1
            }
        case .nearLane3:
            switch level {
            case .calm, .slow, .medium: return 0
            case .fast, .veryFast: return 1
            }
        default:
            return 0
        }
    }

    /// Adds one subtle, non-sparkling mid accent to a different lane at each activity tier.
    func midAccentParticleCount(for level: TokenActivityLevel) -> Int {
        switch self {
        case .midLane1:
            return level == .calm ? 0 : 1
        case .midLane2:
            switch level {
            case .calm, .slow: return 0
            case .medium, .fast, .veryFast: return 1
            }
        case .midLane3:
            switch level {
            case .calm, .slow, .medium: return 0
            case .fast, .veryFast: return 1
            }
        case .midLane4:
            return level == .veryFast ? 1 : 0
        default:
            return 0
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
            + ParticleStreamID.farLane1.particleCount(for: self)
            + ParticleStreamID.farLane2.particleCount(for: self)
            + ParticleStreamID.farLane3.particleCount(for: self)
            + ParticleStreamID.farLane4.particleCount(for: self)
    }

    var midParticleCount: Int {
        ParticleStreamID.midLane1.particleCount(for: self)
            + ParticleStreamID.midLane2.particleCount(for: self)
            + ParticleStreamID.midLane3.particleCount(for: self)
            + ParticleStreamID.midLane4.particleCount(for: self)
    }

    var nearParticleCount: Int {
        ParticleStreamID.nearLane1.particleCount(for: self)
            + ParticleStreamID.nearLane2.particleCount(for: self)
            + ParticleStreamID.nearLane3.particleCount(for: self)
    }

    /// Keeps just a handful of mid points subtly brighter, without giving them sparkle.
    var midAccentParticleCount: Int {
        ParticleStreamID.midLane1.midAccentParticleCount(for: self)
            + ParticleStreamID.midLane2.midAccentParticleCount(for: self)
            + ParticleStreamID.midLane3.midAccentParticleCount(for: self)
            + ParticleStreamID.midLane4.midAccentParticleCount(for: self)
    }

    /// Reserves the largest near highlights for fast tiers and keeps them rare.
    var nearHighlightParticleCount: Int {
        ParticleStreamID.nearLane1.highlightParticleCount(for: self)
            + ParticleStreamID.nearLane2.highlightParticleCount(for: self)
            + ParticleStreamID.nearLane3.highlightParticleCount(for: self)
    }

    var particleCount: Int {
        farParticleCount + midParticleCount + nearParticleCount
    }

    var brightParticleCount: Int {
        ParticleStreamID.nearLane1.brightParticleCount(for: self)
            + ParticleStreamID.nearLane2.brightParticleCount(for: self)
            + ParticleStreamID.nearLane3.brightParticleCount(for: self)
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
