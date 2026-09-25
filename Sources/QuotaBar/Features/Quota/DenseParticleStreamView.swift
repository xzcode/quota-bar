import SwiftUI
import CodexQuotaCore

/// Renders soft and bright points in one Canvas using fixed, cached instance descriptors.
struct DenseParticleStreamView: View {
    let level: TokenActivityLevel
    let elapsed: TimeInterval
    let state: QuotaDangerState

    @State private var phaseAnchors = ParticleFlowSystem.streams.map { $0.particles.map(\.phase) }
    @State private var phaseAnchorTime: TimeInterval = 0
    @State private var transitionStart: TimeInterval = 0
    @State private var transitionSourceCounts = ParticleStreamID.allCases.map { $0.particleCount(for: .calm) }
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
        let transitionSourceTotal = transitionSourceCounts.reduce(0, +)
        let transitioning = hasInitialized
            && elapsed - transitionStart < transitionDuration
            && transitionSourceTotal != level.particleCount
        let distance = size.width + wrapMargin * 2
        let violetAccent = QuotaVisualStyle.activityVioletAccent(for: state)

        // Streams are kept in far-to-near order; each lane draws only its own phase sequence.
        for streamIndex in ParticleFlowSystem.streams.indices {
            let stream = ParticleFlowSystem.streams[streamIndex]
            let targetCount = stream.id.particleCount(for: level)
            let sourceCount = transitionSourceCounts[streamIndex]
            let visibleCount = transitioning ? max(sourceCount, targetCount) : targetCount

            for particleIndex in 0..<visibleCount {
                let descriptor = stream.particles[particleIndex]
                let phase = currentPhase(
                    streamIndex: streamIndex,
                    particleIndex: particleIndex,
                    at: elapsed,
                    travelTime: level.particleTravelSeconds,
                    speedMultiplier: stream.id.speedMultiplier
                )
                let x = size.width + wrapMargin - CGFloat(phase) * distance
                let y = laneY[stream.id.lane]
                let presence = presenceOpacity(
                    for: particleIndex,
                    sourceCount: sourceCount,
                    targetCount: targetCount,
                    progress: progress,
                    transitioning: transitioning
                )
                guard presence > 0.001 else { continue }
                let safeZone = textSafeZoneFactors(at: x, width: size.width, layer: stream.depthLayer)
                let violetTint = rightVioletTint(at: x, width: size.width, layer: stream.depthLayer)

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
                        layer: stream.depthLayer,
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
    }

    /// Draws a depth-appropriate core and keeps far particles free of visible halos.
    private func drawSoftParticle(
        in context: inout GraphicsContext,
        descriptor: DenseParticleDescriptor,
        layer: ParticleDepthLayer,
        center: CGPoint,
        color: Color,
        presence: Double,
        opacityMultiplier: Double,
        violetAccent: Color,
        violetTint: Double
    ) {
        let diameter = descriptor.size
        if case .near = layer {
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
        let coverageStart = level.rightVioletCoverageStartX
        let rawProgress = min(1, max(0, (x / width - coverageStart) / max(0.01, 1 - coverageStart)))
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

    /// Establishes all five independently stratified stream anchors when animation starts.
    private func initializePhases() {
        guard !hasInitialized else { return }
        phaseAnchors = ParticleFlowSystem.streams.map { $0.particles.map(\.phase) }
        phaseAnchorTime = elapsed
        transitionStart = elapsed
        transitionSourceCounts = ParticleFlowSystem.streams.map { $0.id.particleCount(for: level) }
        hasInitialized = true
    }

    /// Preserves active stream positions and inserts new points at phase offsets matching that stream.
    private func preservePhases(from oldLevel: TokenActivityLevel, to newLevel: TokenActivityLevel) {
        let now = elapsed
        let inPriorTransition = now - transitionStart < transitionDuration
        let oldTravelTime = max(oldLevel.particleTravelSeconds, 0.1)
        var anchors = phaseAnchors
        var sourceCounts: [Int] = []
        sourceCounts.reserveCapacity(ParticleFlowSystem.streams.count)

        for streamIndex in ParticleFlowSystem.streams.indices {
            let stream = ParticleFlowSystem.streams[streamIndex]
            let oldCount = stream.id.particleCount(for: oldLevel)
            let previousVisibleCount = inPriorTransition ? transitionSourceCounts[streamIndex] : 0
            let sourceCount = max(oldCount, previousVisibleCount)
            let targetCount = stream.id.particleCount(for: newLevel)
            let phaseAdvance = max(0, now - phaseAnchorTime) / oldTravelTime * stream.id.speedMultiplier

            for particleIndex in 0..<sourceCount {
                anchors[streamIndex][particleIndex] = wrappedPhase(phaseAnchors[streamIndex][particleIndex] + phaseAdvance)
            }

            if targetCount > sourceCount {
                // The shared stream offset keeps additions nested with particles that have already moved.
                let streamOffset = sourceCount > 0
                    ? wrappedPhase(anchors[streamIndex][0] - stream.particles[0].phase)
                    : 0
                for particleIndex in sourceCount..<targetCount {
                    anchors[streamIndex][particleIndex] = wrappedPhase(stream.particles[particleIndex].phase + streamOffset)
                }
            }

            sourceCounts.append(sourceCount)
        }

        phaseAnchors = anchors
        transitionSourceCounts = sourceCounts
        phaseAnchorTime = now
        transitionStart = now
        hasInitialized = true
    }

    /// Advances one point at its stream's shared speed and wraps only that point's phase.
    private func currentPhase(
        streamIndex: Int,
        particleIndex: Int,
        at time: TimeInterval,
        travelTime: Double,
        speedMultiplier: Double
    ) -> Double {
        guard hasInitialized else {
            return ParticleFlowSystem.streams[streamIndex].particles[particleIndex].phase
        }
        let raw = phaseAnchors[streamIndex][particleIndex]
            + max(0, time - phaseAnchorTime) / max(travelTime, 0.1) * speedMultiplier
        return wrappedPhase(raw)
    }

    /// Fades only the per-stream additions/removals without restarting any existing stream.
    private func presenceOpacity(
        for particleIndex: Int,
        sourceCount: Int,
        targetCount: Int,
        progress: Double,
        transitioning: Bool
    ) -> Double {
        guard transitioning else { return 1 }
        if targetCount > sourceCount && particleIndex >= sourceCount {
            return progress
        }
        if sourceCount > targetCount && particleIndex >= targetCount {
            return 1 - progress
        }
        return 1
    }

    private func transitionProgress(at time: TimeInterval) -> Double {
        min(1, max(0, (time - transitionStart) / transitionDuration))
    }

    private func wrappedPhase(_ phase: Double) -> Double {
        phase - floor(phase)
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
