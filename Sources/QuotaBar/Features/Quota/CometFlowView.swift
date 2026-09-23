import SwiftUI
import CodexQuotaCore

/// Draws colored comet cores and fine sparks, keeping the bright motion off the text center.
struct CometFlowView: View {
    let level: TokenActivityLevel
    let elapsed: TimeInterval
    let state: QuotaDangerState

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0, level != .calm else { return }
            drawComets(in: &context, size: size)
            drawSparks(in: &context, size: size)
        }
        .allowsHitTesting(false)
    }

    /// Gives each comet a distinct edge lane, phase, and colored gradient trail.
    private func drawComets(in context: inout GraphicsContext, size: CGSize) {
        let colors = QuotaVisualStyle.dynamicEnergyPalette(for: state)
        let travel = max(level.particleTravelSeconds, 0.1)
        let lanes = [0.30, 0.70, 0.45]

        for index in 0..<level.cometCount {
            let speed = 0.84 + Double(index) * 0.11
            let seed = 0.12 + Double(index) * 0.29
            let phase = (elapsed / travel * speed + seed).truncatingRemainder(dividingBy: 1)
            let x = (1 - phase) * size.width
            let wave = sin(elapsed / travel * .pi * 2 * speed + seed * .pi * 4) * 1.8
            let y = size.height * lanes[index] + wave
            let isInTextZone = x >= 55 && x <= 155 && y >= 8 && y <= 24
            let opacity = isInTextZone ? 0.42 : 1.0
            let coreDiameter = level.cometCoreDiameter
            let haloDiameter = coreDiameter + 5
            let core = CGPoint(x: x, y: y)
            let tail = CGPoint(x: x + level.cometTrailLength, y: y + 1.1)
            let path = Path { path in
                path.move(to: tail)
                path.addLine(to: core)
            }
            let trail = Gradient(colors: [
                .clear,
                colors[2].opacity(0.38 * opacity),
                colors[1].opacity(0.72 * opacity),
                colors[0].opacity(0.90 * opacity)
            ])

            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 3.2))
                glow.stroke(
                    path,
                    with: .linearGradient(trail, startPoint: tail, endPoint: core),
                    style: StrokeStyle(lineWidth: 5.2, lineCap: .round)
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
                    Gradient(colors: [colors[0].opacity(0.62 * opacity), colors[1].opacity(0.22 * opacity), .clear]),
                    center: core,
                    startRadius: 0,
                    endRadius: haloDiameter / 2
                )
            )

            let coreRect = CGRect(x: x - coreDiameter / 2, y: y - coreDiameter / 2, width: coreDiameter, height: coreDiameter)
            context.fill(Path(ellipseIn: coreRect), with: .color(Color(red: 0.72, green: 0.94, blue: 1).opacity(opacity)))
            let pinprick = CGRect(x: x - 0.45, y: y - 0.45, width: 0.9, height: 0.9)
            context.fill(Path(ellipseIn: pinprick), with: .color(.white.opacity(0.82 * opacity)))
        }
    }

    /// Keeps sparks as small colored texture rather than the dominant white-particle effect.
    private func drawSparks(in context: inout GraphicsContext, size: CGSize) {
        let colors = QuotaVisualStyle.dynamicEnergyPalette(for: state)
        let travel = max(level.particleTravelSeconds, 0.1)

        for index in 0..<level.sparkCount {
            let speed = 0.64 + Double((index * 5) % 7) * 0.055
            let seed = Double((index * 37 + 19) % 101) / 101
            let phase = (elapsed / travel * speed + seed).truncatingRemainder(dividingBy: 1)
            let x = (1 - phase) * size.width
            let lane = index.isMultiple(of: 2) ? 0.24 : 0.76
            let wave = sin(elapsed / travel * .pi * 2 * speed + seed * .pi * 4) * 1.2
            let y = size.height * lane + wave
            let diameter = 1.0 + Double(index % 3) * 0.45
            let safeZoneFactor = x >= 55 && x <= 155 && y >= 8 && y <= 24 ? 0.38 : 1.0
            let alpha = (0.20 + Double(index % 4) * 0.065) * level.particleOpacityMultiplier * safeZoneFactor
            let rect = CGRect(x: x - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter)
            context.fill(Path(ellipseIn: rect), with: .color(colors[index % colors.count].opacity(alpha)))
        }
    }
}
