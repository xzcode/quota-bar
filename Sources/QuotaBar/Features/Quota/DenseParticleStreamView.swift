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

            if descriptor.isBright {
                drawBrightParticle(
                    in: &context,
                    descriptor: descriptor,
                    center: CGPoint(x: x, y: y),
                    color: brightColors[descriptor.colorIndex],
                    presence: presence
                )
            } else {
                drawSoftParticle(
                    in: &context,
                    descriptor: descriptor,
                    center: CGPoint(x: x, y: y),
                    color: softColors[descriptor.colorIndex],
                    presence: presence
                )
            }
        }
    }

    /// Draws a small subdued point with no line, tail, or per-frame brightness changes.
    private func drawSoftParticle(
        in context: inout GraphicsContext,
        descriptor: DenseParticleDescriptor,
        center: CGPoint,
        color: Color,
        presence: Double
    ) {
        let diameter = descriptor.size
        let rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        context.fill(
            Path(ellipseIn: rect),
            with: .color(color.opacity(descriptor.opacity * presence))
        )
    }

    /// Draws one pale core and a tight halo; the glow stays local and never forms a comet tail.
    private func drawBrightParticle(
        in context: inout GraphicsContext,
        descriptor: DenseParticleDescriptor,
        center: CGPoint,
        color: Color,
        presence: Double
    ) {
        let coreDiameter = descriptor.size
        let haloDiameter = coreDiameter + 4
        let haloRect = CGRect(x: center.x - haloDiameter / 2, y: center.y - haloDiameter / 2, width: haloDiameter, height: haloDiameter)
        context.fill(
            Path(ellipseIn: haloRect),
            with: .radialGradient(
                Gradient(colors: [color.opacity(0.28 * presence), color.opacity(0.10 * presence), .clear]),
                center: center,
                startRadius: 0,
                endRadius: haloDiameter / 2
            )
        )

        let coreRect = CGRect(x: center.x - coreDiameter / 2, y: center.y - coreDiameter / 2, width: coreDiameter, height: coreDiameter)
        context.fill(
            Path(ellipseIn: coreRect),
            with: .color(color.opacity(descriptor.opacity * presence))
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

    /// Re-anchors existing phases and places only new particles into the largest current gaps.
    private func preservePhases(from oldLevel: TokenActivityLevel, to newLevel: TokenActivityLevel) {
        let now = elapsed
        let inPriorTransition = now - transitionStart < transitionDuration
        let sourceCount = max(oldLevel.particleCount, inPriorTransition ? transitionSourceCount : 0)
        let oldTravelTime = max(oldLevel.particleTravelSeconds, 0.1)
        var anchors = phaseAnchors
        var currentPhases: [Double] = []

        for index in 0..<sourceCount {
            let descriptor = DenseParticleDescriptor.all[index]
            let raw = phaseAnchors[index] + max(0, now - phaseAnchorTime) / oldTravelTime * descriptor.speedMultiplier
            let phase = raw - floor(raw)
            anchors[index] = phase
            currentPhases.append(phase)
        }

        if newLevel.particleCount > sourceCount {
            let newPhases = DenseParticleDescriptor.fillLargestGaps(
                around: currentPhases,
                count: newLevel.particleCount - sourceCount
            )
            for (offset, phase) in newPhases.enumerated() {
                anchors[sourceCount + offset] = phase
            }
        }

        phaseAnchors = anchors
        phaseAnchorTime = now
        transitionStart = now
        transitionSourceCount = sourceCount
        hasInitialized = true
    }

    /// Advances continuously from the last level-change anchor and wraps only outside the capsule.
    private func currentPhase(for index: Int, at time: TimeInterval, travelTime: Double) -> Double {
        guard hasInitialized else { return DenseParticleDescriptor.all[index].phase }
        let descriptor = DenseParticleDescriptor.all[index]
        let raw = phaseAnchors[index] + max(0, time - phaseAnchorTime) / max(travelTime, 0.1) * descriptor.speedMultiplier
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

/// Immutable per-particle settings are calculated once and shared by all animation frames.
private struct DenseParticleDescriptor {
    let phase: Double
    let lane: Int
    let speedMultiplier: Double
    let size: CGFloat
    let opacity: Double
    let colorIndex: Int
    let isBright: Bool

    // One bright marker per eight stable particle IDs keeps highlight density proportional by tier.
    static let brightIndices = Set(stride(from: 2, to: TokenActivityLevel.veryFast.particleCount, by: 8))
    static let all: [DenseParticleDescriptor] = {
        let phases = stratifiedPhases()
        return phases.indices.map { index in
            let isBright = brightIndices.contains(index)
            let sizeSeed = seed(index, salt: 1)
            let opacitySeed = seed(index, salt: 2)
            let speedSeed = seed(index, salt: 3)
            return DenseParticleDescriptor(
                phase: phases[index],
                lane: index % 5,
                speedMultiplier: 0.90 + speedSeed * 0.20,
                size: isBright ? 2.4 + sizeSeed * 0.8 : 1.4 + sizeSeed * 0.8,
                opacity: isBright ? 0.78 + opacitySeed * 0.20 : 0.34 + opacitySeed * 0.18,
                colorIndex: index % 3,
                isBright: isBright
            )
        }
    }()

    /// Builds nested evenly spaced phase sets, so higher tiers fill gaps without moving existing IDs.
    private static func stratifiedPhases() -> [Double] {
        let slowCount = TokenActivityLevel.slow.particleCount
        let mediumCount = TokenActivityLevel.medium.particleCount
        let fastCount = TokenActivityLevel.fast.particleCount
        let maximumCount = TokenActivityLevel.veryFast.particleCount
        var phases = (0..<slowCount).map { (Double($0) + 0.5) / Double(slowCount) }
        phases += fillLargestGaps(around: phases, count: mediumCount - phases.count)
        phases += fillLargestGaps(around: phases, count: fastCount - phases.count)
        phases += fillLargestGaps(around: phases, count: maximumCount - phases.count)
        return phases
    }

    /// Inserts new phase seeds midway through the widest circular gaps in a deterministic order.
    static func fillLargestGaps(around existing: [Double], count: Int) -> [Double] {
        guard count > 0 else { return [] }
        var phases = existing.sorted()
        var additions: [Double] = []

        for _ in 0..<count {
            var largestGap = -Double.infinity
            var midpoint = 0.0
            for index in phases.indices {
                let left = phases[index]
                let right = index == phases.count - 1 ? phases[0] + 1 : phases[index + 1]
                let gap = right - left
                if gap > largestGap {
                    largestGap = gap
                    midpoint = (left + gap / 2).truncatingRemainder(dividingBy: 1)
                }
            }
            additions.append(midpoint)
            phases.append(midpoint)
            phases.sort()
        }
        return additions
    }

    /// Produces stable pseudo-random-looking variation without runtime randomness or per-frame work.
    private static func seed(_ index: Int, salt: Double) -> Double {
        let value = sin(Double(index + 1) * 12.9898 + salt * 78.233) * 43_758.5453
        return value - floor(value)
    }
}
