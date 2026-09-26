import SwiftUI
import CodexQuotaCore

/// Draws all organic lane emitters into one Canvas driven by the parent's shared TimelineView.
struct DenseParticleStreamView: View {
    let level: TokenActivityLevel
    let elapsed: TimeInterval
    let state: QuotaDangerState

    @State private var emitters: [ParticleEmitterState] = []
    @State private var lastElapsed: TimeInterval?
    @State private var lastWidth: CGFloat = 0

    private let laneY: [CGFloat] = [6.5, 11.5, 16, 20.5, 25.5]
    private let wrapMargin: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard size.width > 0, size.height > 0, level != .calm, !emitters.isEmpty else { return }
                drawEnergyFilaments(in: &context, size: size)
                drawParticles(in: &context, size: size)
            }
            .allowsHitTesting(false)
            .onAppear {
                initializeEmitters(width: geometry.size.width)
            }
            .onChange(of: elapsed) { _, newElapsed in
                advanceEmitters(to: newElapsed, level: level, width: geometry.size.width)
            }
            .onChange(of: level) { oldLevel, newLevel in
                changeActivity(from: oldLevel, to: newLevel, width: geometry.size.width)
            }
            .onChange(of: geometry.size.width) { oldWidth, newWidth in
                resizeEmitters(from: oldWidth, to: newWidth)
            }
        }
        .allowsHitTesting(false)
    }

    /// Seeds each lane once per view lifetime; the process seed varies the arrangement per launch.
    private func initializeEmitters(width: CGFloat) {
        guard emitters.isEmpty, width > 0 else { return }
        emitters = ParticleFlowSystem.makeEmitters(
            for: level,
            width: width,
            wrapMargin: wrapMargin,
            at: elapsed
        )
        lastElapsed = elapsed
        lastWidth = width
    }

    /// Integrates only the elapsed frame delta; a delayed frame cannot create a giant position jump.
    private func advanceEmitters(to time: TimeInterval, level: TokenActivityLevel, width: CGFloat) {
        guard !emitters.isEmpty else {
            initializeEmitters(width: width)
            return
        }
        guard width > 0 else { return }
        let previousTime = lastElapsed ?? time
        let delta = min(0.10, max(0, time - previousTime))
        for index in emitters.indices {
            ParticleFlowSystem.advance(
                &emitters[index],
                by: delta,
                level: level,
                width: width,
                wrapMargin: wrapMargin,
                at: time
            )
        }
        lastElapsed = time
    }

    /// Keeps existing particles moving while count changes add into gaps or softly retire points.
    private func changeActivity(from oldLevel: TokenActivityLevel, to newLevel: TokenActivityLevel, width: CGFloat) {
        guard !emitters.isEmpty else {
            initializeEmitters(width: width)
            return
        }
        advanceEmitters(to: elapsed, level: oldLevel, width: width)
        for index in emitters.indices {
            ParticleFlowSystem.setTarget(
                &emitters[index],
                level: newLevel,
                width: width,
                at: elapsed
            )
        }
        lastElapsed = elapsed
    }

    /// Preserves relative particle placement if SwiftUI changes the compact capsule width.
    private func resizeEmitters(from oldWidth: CGFloat, to newWidth: CGFloat) {
        guard !emitters.isEmpty, oldWidth > 0, newWidth > 0 else {
            lastWidth = newWidth
            return
        }
        for index in emitters.indices {
            ParticleFlowSystem.resize(
                &emitters[index],
                from: lastWidth > 0 ? lastWidth : oldWidth,
                to: newWidth,
                wrapMargin: wrapMargin
            )
        }
        lastWidth = newWidth
    }

    /// Draws independent streams back-to-front and applies the existing label-safe visual treatment.
    private func drawParticles(in context: inout GraphicsContext, size: CGSize) {
        let softColors = QuotaVisualStyle.softEnergyParticlePalette(for: state)
        let brightColors = QuotaVisualStyle.brightEnergyParticlePalette(for: state)
        let violetAccent = QuotaVisualStyle.activityVioletAccent(for: state)

        for emitter in emitters {
            let stream = emitter.stream
            for particle in emitter.particles {
                let descriptor = particle.descriptor
                let x = particle.x
                // Stable orbital offsets dissolve horizontal rows into a volumetric stream.
                let y = laneY[stream.id.lane] + sin(x / 38 + descriptor.twinklePhase) * 1.7
                let presence = particle.presence(at: elapsed)
                guard presence > 0.001 else { continue }
                let safeZone = textSafeZoneFactors(at: x, width: size.width, layer: stream.depthLayer)
                let violetTint = rightVioletTint(at: x, width: size.width, layer: stream.depthLayer)

                if stream.depthLayer == .near || descriptor.isMidAccent {
                    drawCometTail(in: &context, center: CGPoint(x: x, y: y),
                                  color: softColors[descriptor.colorIndex],
                                  diameter: descriptor.size, bright: descriptor.isBright,
                                  opacity: presence * safeZone.particleOpacity * descriptor.opacity)
                }

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
                        haloStrengthMultiplier: stream.effectMultiplier,
                        sparkle: sparkleSample(
                            for: descriptor,
                            at: elapsed,
                            depthScale: safeZone.sparkleDepth * stream.effectMultiplier
                        )
                    )
                } else {
                    let haloStrength: Double
                    switch stream.depthLayer {
                    case .far:
                        haloStrength = 0
                    case .mid:
                        haloStrength = descriptor.isMidAccent ? 0.05 : 0
                    case .near:
                        haloStrength = 0.12 * stream.effectMultiplier
                    }
                    drawSoftParticle(
                        in: &context,
                        descriptor: descriptor,
                        center: CGPoint(x: x, y: y),
                        color: softColors[descriptor.colorIndex],
                        presence: presence,
                        opacityMultiplier: safeZone.particleOpacity,
                        violetAccent: violetAccent,
                        violetTint: violetTint,
                        haloStrength: haloStrength
                    )
                }
            }
        }
    }

    /// Four plasma threads share the particle clock and Canvas, avoiding extra timers and views.
    private func drawEnergyFilaments(in context: inout GraphicsContext, size: CGSize) {
        let colors = QuotaVisualStyle.softEnergyParticlePalette(for: state)
        for index in 0..<4 {
            var path = Path()
            let phase = Double(index) * 1.7
            for step in 0...48 {
                let x = size.width * Double(step) / 48
                let normalizedX = x / size.width
                // Edge-weighted excursions frame the readout without an opaque central mask.
                let envelope = 0.35 + 0.65 * abs(normalizedX - 0.5) * 2
                let y = size.height * (index.isMultiple(of: 2) ? 0.23 : 0.77)
                    + sin(normalizedX * 7 + elapsed * (0.45 + reactorIntensity) + phase) * 4 * envelope
                let point = CGPoint(x: x, y: y)
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            let color = colors[index % colors.count]
            let shading = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [color.opacity(0.7), color.opacity(0.08), color.opacity(0.55)]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)
            )
            var glow = context
            glow.opacity = 0.12 + reactorIntensity * 0.12
            glow.stroke(path, with: shading, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            context.stroke(path, with: shading, style: StrokeStyle(lineWidth: 0.55, lineCap: .round))
        }
    }

    /// Left-moving near particles leave a tapered luminous wake extending to the right.
    private func drawCometTail(in context: inout GraphicsContext, center: CGPoint, color: Color,
                               diameter: CGFloat, bright: Bool, opacity: Double) {
        let length = (bright ? 10.0 : 4.0) + reactorIntensity * (bright ? 17 : 9)
        let thickness = max(0.7, diameter * (bright ? 0.5 : 0.28))
        let rect = CGRect(x: center.x, y: center.y - thickness / 2, width: length, height: thickness)
        context.fill(Path(roundedRect: rect, cornerRadius: thickness / 2), with: .linearGradient(
            Gradient(colors: [color.opacity(opacity * 0.65), color.opacity(opacity * 0.15), .clear]),
            startPoint: center, endPoint: CGPoint(x: center.x + length, y: center.y)
        ))
    }

    /// Activity strengthens the wake independently of the quota danger colors.
    private var reactorIntensity: Double {
        switch level {
        case .calm: return 0
        case .slow: return 0.2
        case .medium: return 0.45
        case .fast: return 0.72
        case .veryFast: return 1
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
        violetTint: Double,
        haloStrength: Double
    ) {
        let diameter = descriptor.size
        if haloStrength > 0 {
            let haloDiameter = diameter + 4
            let haloRect = CGRect(x: center.x - haloDiameter / 2, y: center.y - haloDiameter / 2, width: haloDiameter, height: haloDiameter)
            let haloOpacity = haloStrength * presence * opacityMultiplier
            context.fill(
                Path(ellipseIn: haloRect),
                with: .radialGradient(
                    Gradient(colors: [
                        color.opacity(haloOpacity),
                        color.opacity(haloOpacity * 0.30),
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

    /// Draws a bright core with a tight halo; sparkle is limited to selected near particles.
    private func drawBrightParticle(
        in context: inout GraphicsContext,
        descriptor: DenseParticleDescriptor,
        center: CGPoint,
        color: Color,
        presence: Double,
        opacityMultiplier: Double,
        violetAccent: Color,
        violetTint: Double,
        haloStrengthMultiplier: Double,
        sparkle: SparkleSample
    ) {
        let coreDiameter = descriptor.size
        let haloDiameter = (coreDiameter + 8) * sparkle.haloSizeMultiplier
        let haloRect = CGRect(x: center.x - haloDiameter / 2, y: center.y - haloDiameter / 2, width: haloDiameter, height: haloDiameter)
        context.fill(
            Path(ellipseIn: haloRect),
            with: .radialGradient(
                Gradient(colors: [
                    color.opacity(0.28 * presence * opacityMultiplier * haloStrengthMultiplier * sparkle.haloOpacityMultiplier),
                    color.opacity(0.10 * presence * opacityMultiplier * haloStrengthMultiplier * sparkle.haloOpacityMultiplier),
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
            return TextSafeZoneFactors(particleOpacity: 0.90 + 0.10 * smoothProgress, sparkleDepth: 0.55 + 0.45 * smoothProgress)
        case .near:
            return TextSafeZoneFactors(particleOpacity: 0.78 + 0.22 * smoothProgress, sparkleDepth: 0.72 + 0.28 * smoothProgress)
        }
    }

    /// Keeps the established right-side violet coverage and strength responsive to activity.
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

    /// Uses stable per-particle phases for continuous twinkle without frame-random flicker.
    private func sparkleSample(
        for descriptor: DenseParticleDescriptor,
        at time: TimeInterval,
        depthScale: Double
    ) -> SparkleSample {
        guard descriptor.sparkleEnabled else { return .steady }
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
