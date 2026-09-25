import Foundation
import CodexQuotaCore

/// Identifies one independently randomized, fixed-speed emitter for each active depth/lane pair.
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

    /// Lane-specific velocities keep neighboring emitters from synchronizing.
    var speedMultiplier: Double {
        switch self {
        case .farLane0: return 0.58
        case .farLane1: return 0.61
        case .farLane2: return 0.64
        case .farLane3: return 0.60
        case .farLane4: return 0.57
        case .midLane1: return 0.96
        case .midLane2: return 1.00
        case .midLane3: return 1.04
        case .midLane4: return 1.02
        case .nearLane1: return 1.55
        case .nearLane2: return 1.70
        case .nearLane3: return 1.60
        }
    }

    /// Scales every lane from its medium-tier baseline so each activity tier has an exact multiplier.
    func particleCount(for level: TokenActivityLevel) -> Int {
        let mediumBaseline: Int
        switch self {
        case .farLane0, .farLane1, .farLane3, .farLane4: mediumBaseline = 14
        case .farLane2: mediumBaseline = 16
        case .midLane1, .midLane4: mediumBaseline = 10
        case .midLane2, .midLane3: mediumBaseline = 12
        case .nearLane1, .nearLane3: mediumBaseline = 4
        case .nearLane2: mediumBaseline = 8
        }

        switch level {
        case .calm: return 0
        case .slow: return mediumBaseline / 2
        case .medium: return mediumBaseline
        case .fast: return mediumBaseline * 2
        case .veryFast: return mediumBaseline * 4
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

    /// Scales the medium-tier mid accents with the same activity multiplier as the base streams.
    var midAccentParticleCount: Int {
        switch self {
        case .calm: return 0
        case .slow: return 2
        case .medium: return 4
        case .fast: return 8
        case .veryFast: return 16
        }
    }

    /// Scales the medium-tier highlight subset while keeping its share of bright cores fixed.
    var nearHighlightParticleCount: Int {
        switch self {
        case .calm: return 0
        case .slow: return 1
        case .medium: return 2
        case .fast: return 4
        case .veryFast: return 8
        }
    }

    var particleCount: Int {
        farParticleCount + midParticleCount + nearParticleCount
    }

    /// Scales bright near cores with the same 0.5×/1×/2×/4× tier multiplier as base particles.
    var brightParticleCount: Int {
        switch self {
        case .calm: return 0
        case .slow: return 2
        case .medium: return 4
        case .fast: return 8
        case .veryFast: return 16
        }
    }

    /// Keeps the sparkle-enabled particle quota proportional to the bright-core quota.
    var sparkleParticleCount: Int {
        switch self {
        case .calm: return 0
        case .slow: return 2
        case .medium: return 4
        case .fast: return 8
        case .veryFast: return 16
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
