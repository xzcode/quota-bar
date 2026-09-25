import SwiftUI
import CodexQuotaCore

/// A single fixed-lane stream with its own phases, speed, and depth styling.
struct ParticleFlowStream {
    let id: ParticleStreamID
    let depthLayer: ParticleDepthLayer
    let effectMultiplier: Double
    let particles: [DenseParticleDescriptor]
}

/// A cached point descriptor; stream membership and movement are owned by its parent stream.
struct DenseParticleDescriptor {
    let phase: Double
    let size: CGFloat
    let opacity: Double
    let colorIndex: Int
    let isBright: Bool
    let isHighlight: Bool
    let isMidAccent: Bool
    let sparkleRank: Int?
    let sparkleEnabled: Bool
    let twinklePhase: Double
    let twinkleSpeed: Double
    let twinkleDepth: Double
}

/// Visual depth affects rendering only; each stream supplies its own independent velocity.
enum ParticleDepthLayer: Equatable {
    case far
    case mid
    case near
}

/// Precomputes independent, nested jittered phase sequences for all twelve streams exactly once.
enum ParticleFlowSystem {
    private static let nearStreamIDs: [ParticleStreamID] = [.nearLane1, .nearLane2, .nearLane3]
    private static let midStreamIDs: [ParticleStreamID] = [.midLane1, .midLane2, .midLane3, .midLane4]
    private static let nearSelection = makeNearSelection()
    private static let midAccentPoints = makeMidAccentSelection()

    /// Stream ordering is intentionally back-to-front and is reused without per-frame sorting.
    static let streams: [ParticleFlowStream] = ParticleStreamID.allCases.map(makeStream)

    private static func makeStream(_ id: ParticleStreamID) -> ParticleFlowStream {
        let depthLayer = id.depthLayer
        let effectMultiplier = depthLayer == .near && id.lane != 2 ? 0.85 : 1.0
        let phases = phaseDistribution(for: id)
        let particles = phases.indices.map { index in
            let isNear = depthLayer == .near
            let key = ParticlePointKey(stream: id, index: index)
            let isBright = isNear && nearSelection.brightPoints.contains(key)
            let isHighlight = isNear && nearSelection.highlightPoints.contains(key)
            let isMidAccent = depthLayer == .mid && midAccentPoints.contains(key)
            let sizeSeed = seed(index, in: id, salt: 1)
            let opacitySeed = seed(index, in: id, salt: 2)
            let sparkleRank = isNear ? nearSelection.sparkleRanks[key] : nil
            let size: CGFloat
            let opacity: Double

            switch depthLayer {
            case .far:
                size = 1.00 + sizeSeed * 0.50
                opacity = 0.18 + opacitySeed * 0.14
            case .mid:
                size = isMidAccent ? 1.90 + sizeSeed * 0.40 : 1.60 + sizeSeed * 0.70
                opacity = isMidAccent ? 0.50 + opacitySeed * 0.15 : 0.34 + opacitySeed * 0.20
            case .near:
                if isHighlight {
                    size = 3.80 + sizeSeed * 0.40
                    opacity = 0.84 + opacitySeed * 0.11
                } else if isBright {
                    size = 3.20 + sizeSeed * 0.80
                    opacity = 0.78 + opacitySeed * 0.17
                } else {
                    size = 2.60 + sizeSeed * 0.60
                    opacity = 0.58 + opacitySeed * 0.30
                }
            }

            return DenseParticleDescriptor(
                phase: phases[index],
                size: size,
                opacity: opacity,
                colorIndex: (index + id.rawValue) % 3,
                isBright: isBright,
                isHighlight: isHighlight,
                isMidAccent: isMidAccent,
                sparkleRank: sparkleRank,
                sparkleEnabled: sparkleRank != nil,
                twinklePhase: seed(index, in: id, salt: 3) * 2 * .pi,
                twinkleSpeed: 0.9 + seed(index, in: id, salt: 4) * 0.2,
                twinkleDepth: 0.9 + seed(index, in: id, salt: 5) * 0.2
            )
        }

        return ParticleFlowStream(
            id: id,
            depthLayer: depthLayer,
            effectMultiplier: effectMultiplier,
            particles: particles
        )
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

    /// Selects nested bright, highlight, and sparkle points across the three near streams.
    private static func makeNearSelection() -> (
        brightPoints: Set<ParticlePointKey>,
        highlightPoints: Set<ParticlePointKey>,
        sparkleRanks: [ParticlePointKey: Int]
    ) {
        var brightPoints = Set<ParticlePointKey>()
        var highlightPoints = Set<ParticlePointKey>()
        var sparkleRanks: [ParticlePointKey: Int] = [:]
        var previousCounts = Array(repeating: 0, count: nearStreamIDs.count)
        var previousBrightCounts = Array(repeating: 0, count: nearStreamIDs.count)
        var previousHighlightCounts = Array(repeating: 0, count: nearStreamIDs.count)
        var previousSparkleCount = 0

        for level in [TokenActivityLevel.slow, .medium, .fast, .veryFast] {
            var newBrightPoints: [ParticlePointKey] = []
            for streamIndex in nearStreamIDs.indices {
                let id = nearStreamIDs[streamIndex]
                let targetCount = id.particleCount(for: level)
                let band = (previousCounts[streamIndex]..<targetCount).map {
                    ParticlePointKey(stream: id, index: $0)
                }
                previousCounts[streamIndex] = targetCount

                let addedBrightCount = id.brightParticleCount(for: level) - previousBrightCounts[streamIndex]
                let streamBrightPoints = Array(
                    band.sorted { seed($0, salt: 20) < seed($1, salt: 20) }
                        .prefix(addedBrightCount)
                )
                brightPoints.formUnion(streamBrightPoints)
                newBrightPoints.append(contentsOf: streamBrightPoints)

                let addedHighlightCount = id.highlightParticleCount(for: level) - previousHighlightCounts[streamIndex]
                highlightPoints.formUnion(
                    streamBrightPoints.sorted { seed($0, salt: 22) < seed($1, salt: 22) }
                        .prefix(addedHighlightCount)
                )
                previousBrightCounts[streamIndex] = id.brightParticleCount(for: level)
                previousHighlightCounts[streamIndex] = id.highlightParticleCount(for: level)
            }

            let addedSparkleCount = level.sparkleParticleCount - previousSparkleCount
            let newSparklePoints = newBrightPoints
                .sorted { seed($0, salt: 21) < seed($1, salt: 21) }
                .prefix(addedSparkleCount)
            for (offset, key) in newSparklePoints.enumerated() {
                sparkleRanks[key] = previousSparkleCount + offset
            }

            previousSparkleCount = level.sparkleParticleCount
        }

        return (brightPoints, highlightPoints, sparkleRanks)
    }

    /// Chooses a small, nested subset of mid points for restrained brightness and a faint halo.
    private static func makeMidAccentSelection() -> Set<ParticlePointKey> {
        var selected = Set<ParticlePointKey>()
        var previousCounts = Array(repeating: 0, count: midStreamIDs.count)
        var previousAccentCounts = Array(repeating: 0, count: midStreamIDs.count)

        for level in [TokenActivityLevel.slow, .medium, .fast, .veryFast] {
            var band: [ParticlePointKey] = []
            for streamIndex in midStreamIDs.indices {
                let id = midStreamIDs[streamIndex]
                let targetCount = id.particleCount(for: level)
                band.append(contentsOf: (previousCounts[streamIndex]..<targetCount).map {
                    ParticlePointKey(stream: id, index: $0)
                })
                previousCounts[streamIndex] = targetCount
            }

            for streamIndex in midStreamIDs.indices {
                let id = midStreamIDs[streamIndex]
                let targetAccentCount = id.midAccentParticleCount(for: level)
                let additions = targetAccentCount - previousAccentCounts[streamIndex]
                selected.formUnion(
                    band.filter { $0.stream == id }
                        .sorted { seed($0, salt: 30) < seed($1, salt: 30) }
                        .prefix(additions)
                )
                previousAccentCounts[streamIndex] = targetAccentCount
            }
        }

        return selected
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

    private static func seed(_ key: ParticlePointKey, salt: Double) -> Double {
        seed(key.index, in: key.stream, salt: salt)
    }
}

/// A stable address for a particle inside one independent lane/depth stream.
private struct ParticlePointKey: Hashable {
    let stream: ParticleStreamID
    let index: Int
}
