import SwiftUI
import CodexQuotaCore

/// Draws all bright comets and quiet streaks on stable horizontal lanes.
struct CometFlowView: View {
    let level: TokenActivityLevel
    let elapsed: TimeInterval
    let state: QuotaDangerState

    // Fixed y coordinates keep every instance on one of the four compact-bar lanes.
    private let laneY: [CGFloat] = [7, 12, 20, 25]
    private let laneOrder = [0, 3, 0, 3, 1, 2, 1, 2, 0, 3]
    private let phases = [0.08, 0.37, 0.68, 0.91, 0.22, 0.54, 0.82, 0.14, 0.45, 0.74]
    private let speedOffsets = [-0.10, 0.06, 0.12, -0.04, 0.03, -0.12, 0.08, -0.02, 0.11, -0.07]
    private let streakLengths: [CGFloat] = [15, 26, 38, 18, 32, 44, 22, 35, 13, 41]
    private let streakOpacities: [Double] = [0.14, 0.16, 0.18, 0.42, 0.17, 0.25, 0.44, 0.16, 0.29, 0.18]

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0, level != .calm else { return }
            drawStreaks(in: &context, size: size)
            drawComets(in: &context, size: size)
        }
        .allowsHitTesting(false)
    }

    /// Places deterministic streak instances on four lanes with stable speed, length, and opacity.
    private func drawStreaks(in context: inout GraphicsContext, size: CGSize) {
        let colors = QuotaVisualStyle.dynamicEnergyPalette(for: state)
        let margin: CGFloat = 52
        let travelDistance = size.width + margin * 2

        for index in 0..<level.streakCount {
            let phase = wrappedPhase(elapsed, travelTime: level.particleTravelSeconds, speedOffset: speedOffsets[index], phase: phases[index])
            let xHead = size.width + margin - CGFloat(phase) * travelDistance
            let y = laneY[laneOrder[index]]
            let length = streakLengths[index]
            let tail = CGPoint(x: xHead + length, y: y)
            let head = CGPoint(x: xHead, y: y)
            let textOpacity = isInTextSafeZone(x: xHead, length: length) ? 0.45 : 1
            let opacity = streakOpacities[index] * textOpacity
            let color = colors[index % colors.count]
            let path = Path { path in
                path.move(to: tail)
                path.addLine(to: head)
            }
            let gradient = Gradient(colors: [
                .clear,
                color.opacity(opacity * 0.72),
                color.opacity(opacity),
                .clear
            ])

            context.stroke(
                path,
                with: .linearGradient(gradient, startPoint: tail, endPoint: head),
                style: StrokeStyle(lineWidth: index == 8 ? 1.25 : 0.85, lineCap: .round)
            )
        }
    }

    /// Keeps comet core, halo, and tail collinear so the bright point never changes lanes.
    private func drawComets(in context: inout GraphicsContext, size: CGSize) {
        let colors = QuotaVisualStyle.dynamicEnergyPalette(for: state)
        let margin = CGFloat(level.cometTrailLength) + 14
        let travelDistance = size.width + margin * 2

        for index in 0..<level.cometCount {
            let phase = wrappedPhase(elapsed, travelTime: level.particleTravelSeconds, speedOffset: speedOffsets[index + 1], phase: phases[index + 1])
            let x = size.width + margin - CGFloat(phase) * travelDistance
            let y = laneY[[1, 2, 1, 2][index]]
            let core = CGPoint(x: x, y: y)
            let textOpacity = isInTextSafeZone(x: x, length: CGFloat(level.cometTrailLength)) ? 0.45 : 1
            let coreDiameter = CGFloat(level.cometCoreDiameter)
            let haloDiameter = coreDiameter + 5
            let trailLength = CGFloat(level.cometTrailLength) * (1 + speedOffsets[index + 2] * 0.12)
            let tail = CGPoint(x: x + trailLength, y: y)
            let path = Path { path in
                path.move(to: tail)
                path.addLine(to: core)
            }
            let trail = Gradient(colors: [
                .clear,
                colors[2].opacity(0.38 * textOpacity),
                colors[1].opacity(0.72 * textOpacity),
                colors[0].opacity(0.90 * textOpacity)
            ])

            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 2.4))
                glow.stroke(
                    path,
                    with: .linearGradient(trail, startPoint: tail, endPoint: core),
                    style: StrokeStyle(lineWidth: 4.6, lineCap: .round)
                )
            }
            context.stroke(
                path,
                with: .linearGradient(trail, startPoint: tail, endPoint: core),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
            )

            let haloRect = CGRect(x: x - haloDiameter / 2, y: y - haloDiameter / 2, width: haloDiameter, height: haloDiameter)
            context.fill(
                Path(ellipseIn: haloRect),
                with: .radialGradient(
                    Gradient(colors: [colors[0].opacity(0.56 * textOpacity), colors[1].opacity(0.18 * textOpacity), .clear]),
                    center: core,
                    startRadius: 0,
                    endRadius: haloDiameter / 2
                )
            )

            let coreRect = CGRect(x: x - coreDiameter / 2, y: y - coreDiameter / 2, width: coreDiameter, height: coreDiameter)
            context.fill(Path(ellipseIn: coreRect), with: .color(Color(red: 0.82, green: 0.96, blue: 1).opacity(textOpacity)))
            let highlight = CGRect(x: x - 0.45, y: y - 0.45, width: 0.9, height: 0.9)
            context.fill(Path(ellipseIn: highlight), with: .color(.white.opacity(0.86 * textOpacity)))
        }
    }

    /// Computes a continuous wrap phase from fixed instance data and the shared animation clock.
    private func wrappedPhase(
        _ elapsed: TimeInterval,
        travelTime: Double,
        speedOffset: Double,
        phase: Double
    ) -> Double {
        let raw = elapsed / max(travelTime, 0.1) * (1 + speedOffset) + phase
        return raw - floor(raw)
    }

    /// Dims the moving accents as they pass beneath the centered percentage text.
    private func isInTextSafeZone(x: CGFloat, length: CGFloat) -> Bool {
        x >= 55 - length && x <= 155
    }
}
