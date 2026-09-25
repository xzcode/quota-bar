import SwiftUI
import CodexQuotaCore

/// Immutable rendering and spacing configuration for one independent depth/lane emitter.
struct ParticleFlowStream {
    let id: ParticleStreamID
    let depthLayer: ParticleDepthLayer
    let effectMultiplier: Double
    let gapProfile: ParticleGapProfile
}

/// Bounds and preferred center spacing used whenever a particle is recycled.
struct ParticleGapProfile {
    let minimum: CGFloat
    let preferred: CGFloat
    let maximum: CGFloat
}

/// Per-particle visual properties are regenerated when its emitter recycles it.
struct DenseParticleDescriptor {
    let size: CGFloat
    let opacity: Double
    let colorIndex: Int
    let isBright: Bool
    let isHighlight: Bool
    let isMidAccent: Bool
    let sparkleEnabled: Bool
    let twinklePhase: Double
    let twinkleSpeed: Double
    let twinkleDepth: Double
}

/// A live point advances in screen coordinates and may briefly fade during tier changes.
struct OrganicParticle {
    let id: UInt64
    var x: CGFloat
    var descriptor: DenseParticleDescriptor
    var fadeInStart: TimeInterval?
    var fadeOutStart: TimeInterval?

    func presence(at time: TimeInterval) -> Double {
        let duration = 0.24
        if let fadeOutStart {
            return min(1, max(0, 1 - (time - fadeOutStart) / duration))
        }
        if let fadeInStart {
            return min(1, max(0, (time - fadeInStart) / duration))
        }
        return 1
    }
}

/// Mutable simulation state is isolated per lane so random gaps never synchronize globally.
struct ParticleEmitterState {
    let stream: ParticleFlowStream
    var random: LaneRandomNumberGenerator
    var particles: [OrganicParticle]
    var nextParticleID: UInt64
    var targetCount: Int

    var activeCount: Int {
        particles.reduce(into: 0) { count, particle in
            if particle.fadeOutStart == nil { count += 1 }
        }
    }
}

/// Small value-type PRNG: each emitter advances its own SplitMix64 state only on spawn/recycle.
struct LaneRandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextUnit() -> Double {
        Double(nextUInt64() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    mutating func value(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextUnit() * (range.upperBound - range.lowerBound)
    }

    mutating func value(in range: ClosedRange<CGFloat>) -> CGFloat {
        range.lowerBound + CGFloat(nextUnit()) * (range.upperBound - range.lowerBound)
    }

    private mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

/// Creates and advances per-lane organic emitters without introducing additional timelines.
enum ParticleFlowSystem {
    /// A fresh process seed changes the visual arrangement on each app launch, not each frame.
    private static let launchSeed = UInt64.random(in: UInt64.min...UInt64.max)

    /// Back-to-front ordering is stable and shared by initialization, simulation, and drawing.
    static let streams: [ParticleFlowStream] = ParticleStreamID.allCases.map { id in
        ParticleFlowStream(
            id: id,
            depthLayer: id.depthLayer,
            effectMultiplier: id.depthLayer == .near && id.lane != 2 ? 0.85 : 1,
            gapProfile: gapProfile(for: id)
        )
    }

    /// Seeds each emitter independently and starts its particles across the visible capsule.
    static func makeEmitters(
        for level: TokenActivityLevel,
        width: CGFloat,
        wrapMargin: CGFloat,
        at time: TimeInterval
    ) -> [ParticleEmitterState] {
        streams.map { stream in
            let streamSalt = UInt64(stream.id.rawValue + 1) &* 0xD6E8_FEB8_6659_FD93
            var random = LaneRandomNumberGenerator(seed: launchSeed ^ streamSalt)
            let count = stream.id.particleCount(for: level)
            var emitter = ParticleEmitterState(
                stream: stream,
                random: random,
                particles: [],
                nextParticleID: 0,
                targetCount: count
            )

            guard count > 0 else { return emitter }
            let usableWidth = max(width + wrapMargin * 2, 1)
            let slotWidth = usableWidth / CGFloat(count)
            let positions = (0..<count).map { index in
                let center = -wrapMargin + (CGFloat(index) + 0.5) * slotWidth
                return center + random.value(in: -CGFloat(0.42)...CGFloat(0.42)) * slotWidth
            }.sorted()
            emitter.random = random

            for position in positions {
                let particle = makeParticle(in: &emitter, level: level, x: position, at: time)
                emitter.particles.append(particle)
            }
            return emitter
        }
    }

    /// Moves each lane and recycles only particles that have individually crossed the left edge.
    static func advance(
        _ emitter: inout ParticleEmitterState,
        by delta: TimeInterval,
        level: TokenActivityLevel,
        width: CGFloat,
        wrapMargin: CGFloat,
        at time: TimeInterval
    ) {
        guard delta > 0 else { return }
        let distance = max(width + wrapMargin * 2, 1)
        let travelTime = max(level.particleTravelSeconds, 0.1)
        let movement = CGFloat(Double(distance) / travelTime * emitter.stream.id.speedMultiplier * delta)

        for index in emitter.particles.indices {
            emitter.particles[index].x -= movement
        }
        emitter.particles.removeAll { particle in
            guard let fadeOutStart = particle.fadeOutStart else { return false }
            return time - fadeOutStart >= 0.24
        }

        while let recycledIndex = emitter.particles.indices
            .filter({
                emitter.particles[$0].fadeOutStart == nil
                    && emitter.particles[$0].x + emitter.particles[$0].descriptor.size / 2 < -wrapMargin
            })
            .min(by: { emitter.particles[$0].x < emitter.particles[$1].x }) {
            var recycled = emitter.particles.remove(at: recycledIndex)
            let rightmost = emitter.particles
                .filter { $0.fadeOutStart == nil }
                .map(\.x)
                .max() ?? (width + wrapMargin)
            let gap = sampleGap(for: emitter.stream, random: &emitter.random)
            // Keep the emitter's tail anchored to the viewport when its whole queue drifts left.
            let recycleAnchor = max(rightmost, width + wrapMargin)
            recycled.x = recycleAnchor + gap
            recycled.descriptor = makeDescriptor(for: emitter.stream, level: level, random: &emitter.random)
            recycled.fadeInStart = time
            recycled.fadeOutStart = nil
            emitter.particles.append(recycled)
        }

        emitter.particles.sort { $0.x < $1.x }
    }

    /// Grows into current empty space or gently retires a spread of points when activity falls.
    static func setTarget(
        _ emitter: inout ParticleEmitterState,
        level: TokenActivityLevel,
        width: CGFloat,
        at time: TimeInterval
    ) {
        let target = emitter.stream.id.particleCount(for: level)
        let active = emitter.activeCount
        emitter.targetCount = target

        if target > active {
            for _ in active..<target {
                let position = insertionPosition(in: emitter, width: width, random: &emitter.random)
                let particle = makeParticle(in: &emitter, level: level, x: position, at: time)
                emitter.particles.append(particle)
            }
        } else if target < active {
            let sortedActive = emitter.particles.indices
                .filter { emitter.particles[$0].fadeOutStart == nil }
                .sorted { emitter.particles[$0].x < emitter.particles[$1].x }
            let removalCount = active - target
            for ordinal in 0..<removalCount {
                let fraction = Double(ordinal + 1) / Double(removalCount + 1)
                let activePosition = min(sortedActive.count - 1, Int(fraction * Double(sortedActive.count)))
                emitter.particles[sortedActive[activePosition]].fadeOutStart = time
            }
        }

        emitter.particles.sort { $0.x < $1.x }
    }

    /// Rescales positions proportionally if the capsule width changes while the view is alive.
    static func resize(
        _ emitter: inout ParticleEmitterState,
        from oldWidth: CGFloat,
        to newWidth: CGFloat,
        wrapMargin: CGFloat
    ) {
        guard oldWidth > 0, newWidth > 0, oldWidth != newWidth else { return }
        let oldTrack = oldWidth + wrapMargin * 2
        let newTrack = newWidth + wrapMargin * 2
        let scale = newTrack / oldTrack
        for index in emitter.particles.indices {
            emitter.particles[index].x = -wrapMargin + (emitter.particles[index].x + wrapMargin) * scale
        }
        emitter.particles.sort { $0.x < $1.x }
    }

    /// Inserts activity-tier additions into a large current gap instead of as a visible batch.
    private static func insertionPosition(
        in emitter: ParticleEmitterState,
        width: CGFloat,
        random: inout LaneRandomNumberGenerator
    ) -> CGFloat {
        let visiblePositions = emitter.particles
            .filter { $0.fadeOutStart == nil && $0.x >= 0 && $0.x <= width }
            .map(\.x)
            .sorted()
        guard !visiblePositions.isEmpty else {
            return random.value(in: CGFloat.zero...max(width, 1))
        }

        var gaps: [(start: CGFloat, end: CGFloat)] = []
        var previous: CGFloat = 0
        for position in visiblePositions {
            gaps.append((previous, position))
            previous = position
        }
        gaps.append((previous, width))
        let largestGap = gaps.max { ($0.end - $0.start) < ($1.end - $1.start) }!
        let inset = random.value(in: CGFloat(0.30)...CGFloat(0.70))
        return largestGap.start + (largestGap.end - largestGap.start) * inset
    }

    /// Creates new visual attributes at emitter startup, tier growth, and every recycle.
    private static func makeParticle(
        in emitter: inout ParticleEmitterState,
        level: TokenActivityLevel,
        x: CGFloat,
        at time: TimeInterval
    ) -> OrganicParticle {
        let particle = OrganicParticle(
            id: emitter.nextParticleID,
            x: x,
            descriptor: makeDescriptor(for: emitter.stream, level: level, random: &emitter.random),
            fadeInStart: time,
            fadeOutStart: nil
        )
        emitter.nextParticleID &+= 1
        return particle
    }

    /// Samples layer-specific size and restrained near-only sparkle from the lane's private RNG.
    private static func makeDescriptor(
        for stream: ParticleFlowStream,
        level: TokenActivityLevel,
        random: inout LaneRandomNumberGenerator
    ) -> DenseParticleDescriptor {
        let isNear = stream.depthLayer == .near
        let isMid = stream.depthLayer == .mid
        let nearCount = max(level.nearParticleCount, 1)
        let brightChance = min(1, Double(level.brightParticleCount) / Double(nearCount))
        let isBright = isNear && random.nextUnit() < brightChance
        let highlightChance = level.brightParticleCount > 0
            ? Double(level.nearHighlightParticleCount) / Double(level.brightParticleCount)
            : 0
        let isHighlight = isBright && random.nextUnit() < highlightChance
        let sparkleChance = level.brightParticleCount > 0
            ? Double(level.sparkleParticleCount) / Double(level.brightParticleCount)
            : 0
        let sparkleEnabled = isBright && random.nextUnit() < sparkleChance
        let midChance = level.midParticleCount > 0
            ? Double(level.midAccentParticleCount) / Double(level.midParticleCount)
            : 0
        let isMidAccent = isMid && random.nextUnit() < midChance

        let size: CGFloat
        let opacity: Double
        switch stream.depthLayer {
        case .far:
            size = random.value(in: CGFloat(1.0)...CGFloat(1.6))
            opacity = random.value(in: Double(0.18)...Double(0.32))
        case .mid:
            let midSizeRange = isMidAccent
                ? CGFloat(2.0)...CGFloat(2.5)
                : CGFloat(1.6)...CGFloat(2.5)
            let midOpacityRange = isMidAccent
                ? Double(0.50)...Double(0.60)
                : Double(0.34)...Double(0.54)
            size = random.value(in: midSizeRange)
            opacity = random.value(in: midOpacityRange)
        case .near:
            if isHighlight {
                size = random.value(in: CGFloat(4.0)...CGFloat(4.6))
                opacity = random.value(in: Double(0.86)...Double(0.96))
            } else if isBright {
                size = random.value(in: CGFloat(3.4)...CGFloat(4.2))
                opacity = random.value(in: Double(0.78)...Double(0.94))
            } else {
                size = random.value(in: CGFloat(2.8)...CGFloat(3.6))
                opacity = random.value(in: Double(0.58)...Double(0.88))
            }
        }

        return DenseParticleDescriptor(
            size: size,
            opacity: opacity,
            colorIndex: Int(random.nextUnit() * 3),
            isBright: isBright,
            isHighlight: isHighlight,
            isMidAccent: isMidAccent,
            sparkleEnabled: sparkleEnabled,
            twinklePhase: random.value(in: Double.zero...(2 * Double.pi)),
            twinkleSpeed: random.value(in: Double(0.9)...Double(1.1)),
            twinkleDepth: random.value(in: Double(0.9)...Double(1.1))
        )
    }

    /// Keeps randomized recycle gaps inside the depth profile's perceptually safe bounds.
    private static func sampleGap(
        for stream: ParticleFlowStream,
        random: inout LaneRandomNumberGenerator
    ) -> CGFloat {
        let profile = stream.gapProfile
        let variation = CGFloat(random.value(in: Double(0.75)...Double(1.30)))
        return min(profile.maximum, max(profile.minimum, profile.preferred * variation))
    }

    /// Gives adjacent lanes subtly different preferred gaps to avoid repeated cross-lane texture.
    private static func gapProfile(for id: ParticleStreamID) -> ParticleGapProfile {
        switch id {
        case .farLane0: return ParticleGapProfile(minimum: 4, preferred: 7.5, maximum: 12)
        case .farLane1: return ParticleGapProfile(minimum: 4, preferred: 8.5, maximum: 13)
        case .farLane2: return ParticleGapProfile(minimum: 5, preferred: 9, maximum: 14)
        case .farLane3: return ParticleGapProfile(minimum: 5, preferred: 10, maximum: 15)
        case .farLane4: return ParticleGapProfile(minimum: 4, preferred: 8, maximum: 12)
        case .midLane1: return ParticleGapProfile(minimum: 6, preferred: 11, maximum: 16)
        case .midLane2: return ParticleGapProfile(minimum: 7, preferred: 13, maximum: 20)
        case .midLane3: return ParticleGapProfile(minimum: 7, preferred: 14.5, maximum: 22)
        case .midLane4: return ParticleGapProfile(minimum: 6, preferred: 12.5, maximum: 18)
        case .nearLane1: return ParticleGapProfile(minimum: 10, preferred: 18, maximum: 26)
        case .nearLane2: return ParticleGapProfile(minimum: 11, preferred: 22, maximum: 30)
        case .nearLane3: return ParticleGapProfile(minimum: 10, preferred: 24, maximum: 32)
        }
    }
}

/// Stable lane identifiers determine depth, vertical position, and the local stream velocity.
enum ParticleDepthLayer: Equatable {
    case far
    case mid
    case near
}
