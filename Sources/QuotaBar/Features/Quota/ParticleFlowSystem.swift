import SwiftUI
import CodexQuotaCore

/// A single fixed-lane stream with its own phases, speed, and depth styling.
struct ParticleFlowStream {
    let id: ParticleStreamID
    let depthLayer: ParticleDepthLayer
    let particles: [DenseParticleDescriptor]
}

/// A cached point descriptor; stream membership and movement are owned by its parent stream.
struct DenseParticleDescriptor {
    let phase: Double
    let size: CGFloat
    let opacity: Double
    let colorIndex: Int
    let isBright: Bool
    let sparkleRank: Int?
    let sparkleEnabled: Bool
    let twinklePhase: Double
    let twinkleSpeed: Double
    let twinkleDepth: Double
}

/// Visual depth affects rendering only; each stream supplies its own independent velocity.
enum ParticleDepthLayer {
    case far
    case mid
    case near
}

/// Precomputes independent, nested jittered phase sequences for all five streams exactly once.
enum ParticleFlowSystem {
    private static let nearSelection = makeNearSelection()

    /// Stream ordering is intentionally back-to-front and is reused without per-frame sorting.
    static let streams: [ParticleFlowStream] = ParticleStreamID.allCases.map(makeStream)

    private static func makeStream(_ id: ParticleStreamID) -> ParticleFlowStream {
        let depthLayer: ParticleDepthLayer
        switch id {
        case .farLane0, .farLane4: depthLayer = .far
        case .midLane1, .midLane3: depthLayer = .mid
        case .nearLane2: depthLayer = .near
        }

        let phases = phaseDistribution(for: id)
        let particles = phases.indices.map { index in
            let isNear = depthLayer == .near
            let isBright = isNear && nearSelection.brightIndices.contains(index)
            let sizeSeed = seed(index, in: id, salt: 1)
            let opacitySeed = seed(index, in: id, salt: 2)
            let sparkleRank = isNear ? nearSelection.sparkleRanks[index] : nil
            let size: CGFloat
            let opacity: Double

            switch depthLayer {
            case .far:
                size = 0.70 + sizeSeed * 0.50
                opacity = 0.08 + opacitySeed * 0.12
            case .mid:
                size = 1.20 + sizeSeed * 0.70
                opacity = 0.18 + opacitySeed * 0.24
            case .near:
                size = isBright ? 2.80 + sizeSeed * 0.80 : 2.00 + sizeSeed * 1.10
                opacity = isBright ? 0.68 + opacitySeed * 0.27 : 0.48 + opacitySeed * 0.36
            }

            return DenseParticleDescriptor(
                phase: phases[index],
                size: size,
                opacity: opacity,
                colorIndex: (index + id.rawValue) % 3,
                isBright: isBright,
                sparkleRank: sparkleRank,
                sparkleEnabled: sparkleRank != nil,
                twinklePhase: seed(index, in: id, salt: 3) * 2 * .pi,
                twinkleSpeed: 0.9 + seed(index, in: id, salt: 4) * 0.2,
                twinkleDepth: 0.9 + seed(index, in: id, salt: 5) * 0.2
            )
        }

        return ParticleFlowStream(id: id, depthLayer: depthLayer, particles: particles)
    }

    /// Builds a stream's phase sequence independently, preserving earlier-tier points as it grows.
    private static func phaseDistribution(for id: ParticleStreamID) -> [Double] {
        let initialCount = id.particleCount(for: .slow)
        let slotWidth = 1.0 / Double(initialCount)
        var phases = (0..<initialCount).map { index in
            let center = (Double(index) + 0.5) * slotWidth
            let jitter = (seed(index, in: id, salt: 6) - 0.5) * slotWidth * 0.55
            return center + jitter
        }
        var previousCount = initialCount

        for level in [TokenActivityLevel.medium, .fast, .veryFast] {
            let additions = id.particleCount(for: level) - previousCount
            let orderedPhases = phases.sorted()
            let averageGap = 1.0 / Double(orderedPhases.count)
            let rankedGaps = orderedPhases.indices.map { index -> (index: Int, start: Double, end: Double, score: Double) in
                let start = orderedPhases[index]
                let end = index == orderedPhases.count - 1 ? orderedPhases[0] + 1 : orderedPhases[index + 1]
                let gapBalance = min(2, (end - start) / averageGap)
                let stableJitter = seed(index + level.particleCount, in: id, salt: 7)
                return (index, start, end, gapBalance * 0.65 + stableJitter * 0.35)
            }
            let selectedGaps = rankedGaps.sorted { lhs, rhs in
                lhs.score == rhs.score ? lhs.index < rhs.index : lhs.score > rhs.score
            }.prefix(additions)

            // Every inserted point splits its own stream's gap with a bounded, stable offset.
            let newPhases = selectedGaps.map { gap in
                let split = 0.35 + seed(gap.index + level.particleCount, in: id, salt: 8) * 0.30
                return (gap.start + (gap.end - gap.start) * split).truncatingRemainder(dividingBy: 1)
            }
            phases.append(contentsOf: newPhases)
            previousCount = id.particleCount(for: level)
        }

        assert(phases.count == id.particleCount(for: .veryFast))
        return phases
    }

    /// Selects a nested bright and sparkle subset only from the near stream.
    private static func makeNearSelection() -> (brightIndices: Set<Int>, sparkleRanks: [Int: Int]) {
        var brightIndices = Set<Int>()
        var sparkleRanks: [Int: Int] = [:]
        var previousParticleCount = 0
        var previousBrightCount = 0
        var previousSparkleCount = 0

        for level in [TokenActivityLevel.slow, .medium, .fast, .veryFast] {
            let band = previousParticleCount..<ParticleStreamID.nearLane2.particleCount(for: level)
            let addedBrightCount = level.brightParticleCount - previousBrightCount
            let newBrightIndices = Array(
                band.sorted { seed($0, in: .nearLane2, salt: 20) < seed($1, in: .nearLane2, salt: 20) }
                    .prefix(addedBrightCount)
            )
            brightIndices.formUnion(newBrightIndices)

            let addedSparkleCount = level.sparkleParticleCount - previousSparkleCount
            let newSparkleIndices = newBrightIndices
                .sorted { seed($0, in: .nearLane2, salt: 21) < seed($1, in: .nearLane2, salt: 21) }
                .prefix(addedSparkleCount)
            for (offset, index) in newSparkleIndices.enumerated() {
                sparkleRanks[index] = previousSparkleCount + offset
            }

            previousParticleCount = ParticleStreamID.nearLane2.particleCount(for: level)
            previousBrightCount = level.brightParticleCount
            previousSparkleCount = level.sparkleParticleCount
        }

        return (brightIndices, sparkleRanks)
    }

    /// Produces deterministic seed variation per stream without runtime randomness.
    private static func seed(_ index: Int, in stream: ParticleStreamID, salt: Double) -> Double {
        let value = sin(
            Double(index + 1) * 12.9898
                + Double(stream.rawValue + 1) * 78.233
                + salt * 37.719
        ) * 43_758.5453
        return value - floor(value)
    }
}
