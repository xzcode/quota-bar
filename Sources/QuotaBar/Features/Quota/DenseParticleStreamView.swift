import SwiftUI
import CodexQuotaCore

/// Renders soft and bright points in one Canvas using fixed, cached instance descriptors.
struct DenseParticleStreamView: View {
    let level: TokenActivityLevel
    let elapsed: TimeInterval
    let state: QuotaDangerState

    @State private var phaseAnchors = DenseParticleDescriptor.all.map(\.phase)
    @State private var phaseAnchorTime: TimeInterval = 0
    @State private var transitionStart: TimeInterval = 0
    @State private var transitionSourceCount = 0
    @State private var hasInitialized = false

    private let laneY: [CGFloat] = [6.5, 11.5, 16, 20.5, 25.5]
    private let laneSpeedMultiplier: [Double] = [0.95, 0.97, 1.00, 1.03, 1.05]
    private let wrapMargin: CGFloat = 6
    private let transitionDuration: TimeInterval = 0.28

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0, level != .calm else { return }
            drawParticles(in: &context, size: size)
        }
        .allowsHitTesting(false)
        .onAppear(perform: initializePhases)
        .onChange(of: level) { oldLevel, newLevel in
            preservePhases(from: oldLevel, to: newLevel)
        }
    }

    /// Draws the active set and, during tier changes, fades added or removed points in place.
    private func drawParticles(in context: inout GraphicsContext, size: CGSize) {
        let softColors = QuotaVisualStyle.softEnergyParticlePalette(for: state)
        let brightColors = QuotaVisualStyle.brightEnergyParticlePalette(for: state)
        let progress = transitionProgress(at: elapsed)
        let transitioning = hasInitialized
            && elapsed - transitionStart < transitionDuration
            && transitionSourceCount != level.particleCount
        let visibleCount = transitioning ? max(transitionSourceCount, level.particleCount) : level.particleCount
        let distance = size.width + wrapMargin * 2
        let violetAccent = QuotaVisualStyle.activityVioletAccent(for: state)

        // Render far-to-near so the foreground cores naturally sit above the subdued layers.
        for index in DenseParticleDescriptor.drawOrder where index < visibleCount {
            let descriptor = DenseParticleDescriptor.all[index]
            let phase = currentPhase(for: index, at: elapsed, travelTime: level.particleTravelSeconds)
            let x = size.width + wrapMargin - CGFloat(phase) * distance
            let y = laneY[descriptor.lane]
            let presence = presenceOpacity(for: index, progress: progress, transitioning: transitioning)
            guard presence > 0.001 else { continue }
            let safeZone = textSafeZoneFactors(at: x, width: size.width, layer: descriptor.depthLayer)
            let violetTint = rightVioletTint(at: x, width: size.width, layer: descriptor.depthLayer)

            if descriptor.isBright {
                drawBrightParticle(
                    in: &context,
                    descriptor: descriptor,
                    center: CGPoint(x: x, y: y),
                    color: brightColors[descriptor.colorIndex],
                    presence: presence,
                    opacityMultiplier: safeZone.particleOpacity,
                    violetAccent: violetAccent,
                    violetTint: violetTint,
                    sparkle: sparkleSample(
                        for: descriptor,
                        at: elapsed,
                        depthScale: safeZone.sparkleDepth
                    )
                )
            } else {
                drawSoftParticle(
                    in: &context,
                    descriptor: descriptor,
                    center: CGPoint(x: x, y: y),
                    color: softColors[descriptor.colorIndex],
                    presence: presence,
                    opacityMultiplier: safeZone.particleOpacity,
                    violetAccent: violetAccent,
                    violetTint: violetTint
                )
            }
        }
    }

    /// Draws a depth-appropriate core and keeps far particles free of visible halos.
    private func drawSoftParticle(
        in context: inout GraphicsContext,
        descriptor: DenseParticleDescriptor,
        center: CGPoint,
        color: Color,
        presence: Double,
        opacityMultiplier: Double,
        violetAccent: Color,
        violetTint: Double
    ) {
        let diameter = descriptor.size
        if descriptor.depthLayer == .near {
            let haloDiameter = diameter + 4
            let haloRect = CGRect(x: center.x - haloDiameter / 2, y: center.y - haloDiameter / 2, width: haloDiameter, height: haloDiameter)
            context.fill(
                Path(ellipseIn: haloRect),
                with: .radialGradient(
                    Gradient(colors: [
                        color.opacity(0.12 * presence * opacityMultiplier),
                        color.opacity(0.035 * presence * opacityMultiplier),
                        .clear
                    ]),
                    center: center,
                    startRadius: 0,
                    endRadius: haloDiameter / 2
                )
            )
        }

        let rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        let coreOpacity = descriptor.opacity * presence * opacityMultiplier
        context.fill(
            Path(ellipseIn: rect),
            with: .color(color.opacity(coreOpacity))
        )
        drawVioletTint(in: &context, rect: rect, accent: violetAccent, opacity: coreOpacity * violetTint)
    }

    /// Draws one pale core and a tight halo; the glow stays local and never forms a comet tail.
    private func drawBrightParticle(
        in context: inout GraphicsContext,
        descriptor: DenseParticleDescriptor,
        center: CGPoint,
        color: Color,
        presence: Double,
        opacityMultiplier: Double,
        violetAccent: Color,
        violetTint: Double,
        sparkle: SparkleSample
    ) {
        let coreDiameter = descriptor.size
        let haloDiameter = (coreDiameter + 4) * sparkle.haloSizeMultiplier
        let haloRect = CGRect(x: center.x - haloDiameter / 2, y: center.y - haloDiameter / 2, width: haloDiameter, height: haloDiameter)
        context.fill(
            Path(ellipseIn: haloRect),
            with: .radialGradient(
                Gradient(colors: [
                    color.opacity(0.28 * presence * opacityMultiplier * sparkle.haloOpacityMultiplier),
                    color.opacity(0.10 * presence * opacityMultiplier * sparkle.haloOpacityMultiplier),
                    .clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: haloDiameter / 2
            )
        )

        let coreRect = CGRect(x: center.x - coreDiameter / 2, y: center.y - coreDiameter / 2, width: coreDiameter, height: coreDiameter)
        let coreOpacity = descriptor.opacity * presence * opacityMultiplier * sparkle.coreMultiplier
        context.fill(
            Path(ellipseIn: coreRect),
            with: .color(color.opacity(coreOpacity))
        )
        drawVioletTint(in: &context, rect: coreRect, accent: violetAccent, opacity: coreOpacity * violetTint)
    }

    /// Applies a violet bias only to middle and near particle cores at the right side of the capsule.
    private func drawVioletTint(in context: inout GraphicsContext, rect: CGRect, accent: Color, opacity: Double) {
        guard opacity > 0.001 else { return }
        context.fill(Path(ellipseIn: rect), with: .color(accent.opacity(opacity)))
    }

    /// Smoothly protects the labels more strongly for near particles than for the quiet far layer.
    private func textSafeZoneFactors(at x: CGFloat, width: CGFloat, layer: ParticleDepthLayer) -> TextSafeZoneFactors {
        let distanceFromCenter = abs(x / width - 0.5)
        let rawProgress = min(1, max(0, (distanceFromCenter - 0.15) / 0.07))
        let smoothProgress = rawProgress * rawProgress * (3 - 2 * rawProgress)
        switch layer {
        case .far:
            return TextSafeZoneFactors(particleOpacity: 1, sparkleDepth: 0)
        case .mid:
            return TextSafeZoneFactors(particleOpacity: 0.78 + 0.22 * smoothProgress, sparkleDepth: 0.20 + 0.80 * smoothProgress)
        case .near:
            return TextSafeZoneFactors(particleOpacity: 0.55 + 0.45 * smoothProgress, sparkleDepth: 0.45 + 0.55 * smoothProgress)
        }
    }

    /// Eases the violet bias from x=65% to the capsule's right edge.
    private func rightVioletTint(at x: CGFloat, width: CGFloat, layer: ParticleDepthLayer) -> Double {
        let layerWeight: Double
        switch layer {
        case .far: layerWeight = 0
        case .mid: layerWeight = 0.65
        case .near: layerWeight = 1
        }
        let rawProgress = min(1, max(0, (x / width - 0.65) / 0.35))
        let smoothProgress = rawProgress * rawProgress * (3 - 2 * rawProgress)
        return level.rightVioletParticleTint * layerWeight * smoothProgress
    }

    /// Uses the shared timeline and cached descriptor seeds for asynchronous, continuous twinkle.
    private func sparkleSample(
        for descriptor: DenseParticleDescriptor,
        at time: TimeInterval,
        depthScale: Double
    ) -> SparkleSample {
        guard descriptor.sparkleEnabled,
              let rank = descriptor.sparkleRank,
              rank < level.sparkleParticleCount else {
            return .steady
        }

        let wave = 0.5 + 0.5 * sin(
            2 * .pi * time * level.sparkleFrequencyHz * descriptor.twinkleSpeed
                + descriptor.twinklePhase
        )
        let depth = min(0.38, level.sparkleDepth * descriptor.twinkleDepth * depthScale)
        return SparkleSample(
            coreMultiplier: 1 - depth + wave * depth,
            haloOpacityMultiplier: 1 + (0.8 + 0.4 * wave - 1) * depthScale,
            haloSizeMultiplier: 1 + (0.95 + 0.10 * wave - 1) * depthScale
        )
    }

    /// Establishes each particle's initial stratified phase once when the animated layer appears.
    private func initializePhases() {
        guard !hasInitialized else { return }
        phaseAnchors = DenseParticleDescriptor.all.map(\.phase)
        phaseAnchorTime = elapsed
        transitionStart = elapsed
        transitionSourceCount = level.particleCount
        hasInitialized = true
    }

    /// Preserves visible particles and introduces additions at their deterministic descriptor phases.
    private func preservePhases(from oldLevel: TokenActivityLevel, to newLevel: TokenActivityLevel) {
        let now = elapsed
        let inPriorTransition = now - transitionStart < transitionDuration
        let sourceCount = max(oldLevel.particleCount, inPriorTransition ? transitionSourceCount : 0)
        let oldTravelTime = max(oldLevel.particleTravelSeconds, 0.1)
        var anchors = phaseAnchors

        for index in 0..<sourceCount {
            let descriptor = DenseParticleDescriptor.all[index]
            let laneSpeed = laneSpeedMultiplier[descriptor.lane]
            let effectiveTravelTime = oldTravelTime * descriptor.depthLayer.travelTimeMultiplier
            let raw = phaseAnchors[index]
                + max(0, now - phaseAnchorTime) / effectiveTravelTime * laneSpeed
            let phase = raw - floor(raw)
            anchors[index] = phase
        }

        if newLevel.particleCount > sourceCount {
            for index in sourceCount..<newLevel.particleCount {
                anchors[index] = DenseParticleDescriptor.all[index].phase
            }
        }

        phaseAnchors = anchors
        phaseAnchorTime = now
        transitionStart = now
        transitionSourceCount = sourceCount
        hasInitialized = true
    }

    /// Applies one fixed velocity per lane, preserving same-lane spacing while lanes slowly drift apart.
    private func currentPhase(for index: Int, at time: TimeInterval, travelTime: Double) -> Double {
        guard hasInitialized else { return DenseParticleDescriptor.all[index].phase }
        let descriptor = DenseParticleDescriptor.all[index]
        let laneSpeed = laneSpeedMultiplier[descriptor.lane]
        let effectiveTravelTime = max(travelTime, 0.1) * descriptor.depthLayer.travelTimeMultiplier
        let raw = phaseAnchors[index]
            + max(0, time - phaseAnchorTime) / effectiveTravelTime * laneSpeed
        return raw - floor(raw)
    }

    /// Keeps additions and removals visible for a short, smooth transition instead of resetting the set.
    private func presenceOpacity(for index: Int, progress: Double, transitioning: Bool) -> Double {
        guard transitioning else { return 1 }
        if level.particleCount > transitionSourceCount && index >= transitionSourceCount {
            return progress
        }
        if transitionSourceCount > level.particleCount && index >= level.particleCount {
            return 1 - progress
        }
        return 1
    }

    private func transitionProgress(at time: TimeInterval) -> Double {
        min(1, max(0, (time - transitionStart) / transitionDuration))
    }

}

/// Per-particle text-zone adjustments fade smoothly across the edge of the label area.
private struct TextSafeZoneFactors {
    let particleOpacity: Double
    let sparkleDepth: Double
}

/// Multipliers stay at one for non-sparkling particles, avoiding any frame-to-frame brightness drift.
private struct SparkleSample {
    let coreMultiplier: Double
    let haloOpacityMultiplier: Double
    let haloSizeMultiplier: Double

    static let steady = SparkleSample(coreMultiplier: 1, haloOpacityMultiplier: 1, haloSizeMultiplier: 1)
}

/// Assigns each point to a stable depth layer whose speed, size, and brightness travel together.
private enum ParticleDepthLayer: Int {
    case far
    case mid
    case near

    var travelTimeMultiplier: Double {
        switch self {
        case .far: return 1.55
        case .mid: return 1.00
        case .near: return 0.70
        }
    }
}

/// Immutable spatial placement shared by all activity tiers and render frames.
private struct ParticlePlacement {
    let depthLayer: ParticleDepthLayer
    let lane: Int
}

/// Immutable per-particle settings are calculated once and shared by all animation frames.
private struct DenseParticleDescriptor {
    let phase: Double
    let lane: Int
    let depthLayer: ParticleDepthLayer
    let size: CGFloat
    let opacity: Double
    let colorIndex: Int
    let isBright: Bool
    let sparkleRank: Int?
    let sparkleEnabled: Bool
    let twinklePhase: Double
    let twinkleSpeed: Double
    let twinkleDepth: Double

    /// Tier-banded fixed-seed selections preserve each activity level's exact bright/sparkle counts.
    private static let selection = makeSelection()
    static let brightIndices = selection.brightIndices
    private static let sparkleRanks = selection.sparkleRanks
    private static let placements = makePlacements()

    static let all: [DenseParticleDescriptor] = {
        let phases = stratifiedPhases()
        return phases.indices.map { index in
            let isBright = brightIndices.contains(index)
            let sizeSeed = seed(index, salt: 1)
            let opacitySeed = seed(index, salt: 2)
            let sparkleRank = sparkleRanks[index]
            let placement = placements[index]
            let size: CGFloat
            let opacity: Double
            switch placement.depthLayer {
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
                lane: placement.lane,
                depthLayer: placement.depthLayer,
                size: size,
                opacity: opacity,
                colorIndex: index % 3,
                isBright: isBright,
                sparkleRank: sparkleRank,
                sparkleEnabled: sparkleRank != nil,
                twinklePhase: seed(index, salt: 3) * 2 * .pi,
                twinkleSpeed: 0.9 + seed(index, salt: 4) * 0.2,
                twinkleDepth: 0.9 + seed(index, salt: 5) * 0.2
            )
        }
    }()

    /// Builds nested jittered phases by splitting distinct circular gaps with fixed-seed offsets.
    private static func stratifiedPhases() -> [Double] {
        let slowCount = TokenActivityLevel.slow.particleCount
        let maximumCount = TokenActivityLevel.veryFast.particleCount
        let slotWidth = 1.0 / Double(slowCount)
        var phases = (0..<slowCount).map { index in
            let center = (Double(index) + 0.5) * slotWidth
            let jitter = (seed(index, salt: 6) - 0.5) * slotWidth * 0.60
            return center + jitter
        }
        var previousCount = slowCount

        for tier in [TokenActivityLevel.medium, .fast, .veryFast] {
            let additions = tier.particleCount - previousCount
            let orderedPhases = phases.sorted()
            let averageGap = 1.0 / Double(orderedPhases.count)
            let rankedGaps = orderedPhases.indices.map { index -> (index: Int, start: Double, end: Double, score: Double) in
                let start = orderedPhases[index]
                let end = index == orderedPhases.count - 1 ? orderedPhases[0] + 1 : orderedPhases[index + 1]
                let width = end - start
                let gapBalance = min(2, width / averageGap)
                let stableJitter = seed(index + tier.particleCount, salt: 7)
                return (index, start, end, gapBalance * 0.65 + stableJitter * 0.35)
            }
            let chosenGaps = rankedGaps.sorted { lhs, rhs in
                lhs.score == rhs.score ? lhs.index < rhs.index : lhs.score > rhs.score
            }.prefix(additions)

            // Bounded 35–65% splits keep each new particle away from its adjacent points.
            let additionsForTier = chosenGaps.map { gap in
                let fraction = 0.35 + seed(gap.index + tier.particleCount, salt: 8) * 0.30
                return (gap.start + (gap.end - gap.start) * fraction).truncatingRemainder(dividingBy: 1)
            }
            phases.append(contentsOf: additionsForTier)
            previousCount = tier.particleCount
        }

        assert(phases.count == maximumCount)
        return phases
    }

    /// Assigns tier additions to paired outer/middle lanes and the central foreground lane.
    private static func makePlacements() -> [ParticlePlacement] {
        var result: [ParticlePlacement] = []
        var laneUse = Array(repeating: 0, count: 5)
        var previousFar = 0
        var previousMid = 0
        var previousNear = 0

        func append(_ layer: ParticleDepthLayer, count: Int, candidateLanes: [Int]) {
            for _ in 0..<max(0, count) {
                let minimumUse = candidateLanes.map { laneUse[$0] }.min() ?? 0
                let tiedLanes = candidateLanes.filter { laneUse[$0] == minimumUse }
                let index = result.count
                let tieIndex = min(tiedLanes.count - 1, Int(seed(index, salt: 30) * Double(tiedLanes.count)))
                let lane = tiedLanes[tieIndex]
                laneUse[lane] += 1
                result.append(ParticlePlacement(depthLayer: layer, lane: lane))
            }
        }

        for tier in [TokenActivityLevel.slow, .medium, .fast, .veryFast] {
            append(.far, count: tier.farParticleCount - previousFar, candidateLanes: [0, 4])
            append(.mid, count: tier.midParticleCount - previousMid, candidateLanes: [1, 3])
            append(.near, count: tier.nearParticleCount - previousNear, candidateLanes: [2])
            previousFar = tier.farParticleCount
            previousMid = tier.midParticleCount
            previousNear = tier.nearParticleCount
        }

        assert(result.count == TokenActivityLevel.veryFast.particleCount)
        return result
    }

    /// Selects bright points and a nested sparkle subset by fixed-seed ranking inside each tier band.
    private static func makeSelection() -> (brightIndices: Set<Int>, sparkleRanks: [Int: Int]) {
        var brightIndices = Set<Int>()
        var sparkleRanks: [Int: Int] = [:]
        var previousParticleCount = 0
        var previousBrightCount = 0
        var previousSparkleCount = 0

        for tier in [TokenActivityLevel.slow, .medium, .fast, .veryFast] {
            let band = Array(previousParticleCount..<tier.particleCount)
            let addedBrightCount = tier.brightParticleCount - previousBrightCount
            let nearCandidates = band.filter { placements[$0].depthLayer == .near }
            let newBrightIndices = Array(
                nearCandidates.sorted { seed($0, salt: 20) < seed($1, salt: 20) }
                    .prefix(addedBrightCount)
            )
            brightIndices.formUnion(newBrightIndices)

            let addedSparkleCount = tier.sparkleParticleCount - previousSparkleCount
            let newSparkleIndices = newBrightIndices
                .sorted { seed($0, salt: 21) < seed($1, salt: 21) }
                .prefix(addedSparkleCount)
            for (offset, index) in newSparkleIndices.enumerated() {
                sparkleRanks[index] = previousSparkleCount + offset
            }

            previousParticleCount = tier.particleCount
            previousBrightCount = tier.brightParticleCount
            previousSparkleCount = tier.sparkleParticleCount
        }

        return (brightIndices, sparkleRanks)
    }

    /// Produces stable pseudo-random-looking variation without runtime randomness or per-frame work.
    private static func seed(_ index: Int, salt: Double) -> Double {
        let value = sin(Double(index + 1) * 12.9898 + salt * 78.233) * 43_758.5453
        return value - floor(value)
    }

    /// Cached back-to-front order avoids sorting or building layer groups during Canvas rendering.
    static let drawOrder: [Int] = all.indices.sorted {
        if all[$0].depthLayer.rawValue == all[$1].depthLayer.rawValue { return $0 < $1 }
        return all[$0].depthLayer.rawValue < all[$1].depthLayer.rawValue
    }
}
