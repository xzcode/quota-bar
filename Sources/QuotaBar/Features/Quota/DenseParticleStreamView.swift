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
    private let laneSpeedMultiplier: [Double] = [0.93, 1.04, 0.97, 1.08, 1.00]
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

        for index in 0..<visibleCount {
            let descriptor = DenseParticleDescriptor.all[index]
            let phase = currentPhase(for: index, at: elapsed, travelTime: level.particleTravelSeconds)
            let x = size.width + wrapMargin - CGFloat(phase) * distance
            let y = laneY[descriptor.lane]
            let presence = presenceOpacity(for: index, progress: progress, transitioning: transitioning)
            guard presence > 0.001 else { continue }
            let safeZone = textSafeZoneFactors(at: x, width: size.width)

            if descriptor.isBright {
                drawBrightParticle(
                    in: &context,
                    descriptor: descriptor,
                    center: CGPoint(x: x, y: y),
                    color: brightColors[descriptor.colorIndex],
                    presence: presence,
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
                    opacityMultiplier: safeZone.softParticleOpacity
                )
            }
        }
    }

    /// Draws a visible soft core and a faint radial halo without a tail or animated brightness.
    private func drawSoftParticle(
        in context: inout GraphicsContext,
        descriptor: DenseParticleDescriptor,
        center: CGPoint,
        color: Color,
        presence: Double,
        opacityMultiplier: Double
    ) {
        let diameter = descriptor.size
        let haloDiameter = diameter + 4
        let haloRect = CGRect(x: center.x - haloDiameter / 2, y: center.y - haloDiameter / 2, width: haloDiameter, height: haloDiameter)
        context.fill(
            Path(ellipseIn: haloRect),
            with: .radialGradient(
                Gradient(colors: [
                    color.opacity(0.16 * presence * opacityMultiplier),
                    color.opacity(0.05 * presence * opacityMultiplier),
                    .clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: haloDiameter / 2
            )
        )

        let rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        context.fill(
            Path(ellipseIn: rect),
            with: .color(color.opacity(descriptor.opacity * presence * opacityMultiplier))
        )
    }

    /// Draws one pale core and a tight halo; the glow stays local and never forms a comet tail.
    private func drawBrightParticle(
        in context: inout GraphicsContext,
        descriptor: DenseParticleDescriptor,
        center: CGPoint,
        color: Color,
        presence: Double,
        sparkle: SparkleSample
    ) {
        let coreDiameter = descriptor.size
        let haloDiameter = (coreDiameter + 4) * sparkle.haloSizeMultiplier
        let haloRect = CGRect(x: center.x - haloDiameter / 2, y: center.y - haloDiameter / 2, width: haloDiameter, height: haloDiameter)
        context.fill(
            Path(ellipseIn: haloRect),
            with: .radialGradient(
                Gradient(colors: [
                    color.opacity(0.28 * presence * sparkle.haloOpacityMultiplier),
                    color.opacity(0.10 * presence * sparkle.haloOpacityMultiplier),
                    .clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: haloDiameter / 2
            )
        )

        let coreRect = CGRect(x: center.x - coreDiameter / 2, y: center.y - coreDiameter / 2, width: coreDiameter, height: coreDiameter)
        context.fill(
            Path(ellipseIn: coreRect),
            with: .color(color.opacity(descriptor.opacity * presence * sparkle.coreMultiplier))
        )
    }

    /// Smoothly protects the central labels without dimming the bar or a bright particle's core.
    private func textSafeZoneFactors(at x: CGFloat, width: CGFloat) -> TextSafeZoneFactors {
        let distanceFromCenter = abs(x / width - 0.5)
        let rawProgress = min(1, max(0, (distanceFromCenter - 0.15) / 0.07))
        let smoothProgress = rawProgress * rawProgress * (3 - 2 * rawProgress)
        return TextSafeZoneFactors(
            softParticleOpacity: 0.68 + 0.32 * smoothProgress,
            sparkleDepth: 0.52 + 0.48 * smoothProgress
        )
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
            let raw = phaseAnchors[index]
                + max(0, now - phaseAnchorTime) / oldTravelTime * laneSpeed
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
        let raw = phaseAnchors[index]
            + max(0, time - phaseAnchorTime) / max(travelTime, 0.1) * laneSpeed
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
    let softParticleOpacity: Double
    let sparkleDepth: Double
}

/// Multipliers stay at one for non-sparkling particles, avoiding any frame-to-frame brightness drift.
private struct SparkleSample {
    let coreMultiplier: Double
    let haloOpacityMultiplier: Double
    let haloSizeMultiplier: Double

    static let steady = SparkleSample(coreMultiplier: 1, haloOpacityMultiplier: 1, haloSizeMultiplier: 1)
}

/// Immutable per-particle settings are calculated once and shared by all animation frames.
private struct DenseParticleDescriptor {
    let phase: Double
    let lane: Int
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

    static let all: [DenseParticleDescriptor] = {
        let phases = stratifiedPhases()
        return phases.indices.map { index in
            let isBright = brightIndices.contains(index)
            let sizeSeed = seed(index, salt: 1)
            let opacitySeed = seed(index, salt: 2)
            let sparkleRank = sparkleRanks[index]
            return DenseParticleDescriptor(
                phase: phases[index],
                lane: index % 5,
                size: isBright ? 3.8 + sizeSeed * 0.6 : 2.8 + sizeSeed * 0.6,
                opacity: isBright ? 0.78 + opacitySeed * 0.20 : 0.34 + opacitySeed * 0.18,
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

    /// Builds nested jittered strata by splitting each slow-tier interval with stable, bounded offsets.
    private static func stratifiedPhases() -> [Double] {
        let slowCount = TokenActivityLevel.slow.particleCount
        let maximumCount = TokenActivityLevel.veryFast.particleCount
        let slotWidth = 1.0 / Double(slowCount)
        let basePhases = (0..<slowCount).map { index in
            let center = (Double(index) + 0.5) * slotWidth
            let jitter = (seed(index, salt: 6) - 0.5) * slotWidth * 0.60
            return center + jitter
        }

        // Each original slot remains a stratum; higher tiers add one descriptor per stratum per tier.
        let sortedBasePhases = basePhases.sorted()
        let stratumLeftEdges = sortedBasePhases
        let stratumWidths = sortedBasePhases.indices.map { index in
            let next = index == sortedBasePhases.count - 1
                ? sortedBasePhases[0] + 1
                : sortedBasePhases[index + 1]
            return next - sortedBasePhases[index]
        }
        var stratumPoints = Array(repeating: [Double](), count: slowCount)
        var phases = basePhases
        var previousCount = slowCount

        for tier in [TokenActivityLevel.medium, .fast, .veryFast] {
            let additions = tier.particleCount - previousCount
            guard additions % slowCount == 0 else {
                assertionFailure("Activity tiers must add the same number of particles per phase stratum")
                return phases
            }

            let additionsPerStratum = additions / slowCount
            for insertion in 0..<additionsPerStratum {
                var tierPhases: [Double] = []
                tierPhases.reserveCapacity(slowCount)

                for stratum in 0..<slowCount {
                    let points = stratumPoints[stratum].sorted()
                    var leftOffset = 0.0
                    var rightOffset = stratumWidths[stratum]
                    var widestGap = -Double.infinity

                    for pointIndex in 0...points.count {
                        let left = pointIndex == 0 ? 0 : points[pointIndex - 1]
                        let right = pointIndex == points.count ? stratumWidths[stratum] : points[pointIndex]
                        if right - left > widestGap {
                            widestGap = right - left
                            leftOffset = left
                            rightOffset = right
                        }
                    }

                    // Keep each split within 35–65% of its interval to bound both new gaps.
                    let seedIndex = stratum + insertion * slowCount
                    let splitJitter = (seed(seedIndex, salt: Double(tier.particleCount)) - 0.5) * 0.30
                    let offset = leftOffset + (rightOffset - leftOffset) * (0.5 + splitJitter)
                    stratumPoints[stratum].append(offset)
                    tierPhases.append((stratumLeftEdges[stratum] + offset).truncatingRemainder(dividingBy: 1))
                }

                phases.append(contentsOf: tierPhases)
            }
            previousCount = tier.particleCount
        }

        assert(phases.count == maximumCount)
        return phases
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
            let newBrightIndices = Array(
                band.sorted { seed($0, salt: 20) < seed($1, salt: 20) }
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
}
