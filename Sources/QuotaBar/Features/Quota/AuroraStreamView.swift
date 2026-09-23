import SwiftUI
import CodexQuotaCore

/// Draws wide, colored plasma ribbons on lanes above and below the capsule text.
struct AuroraStreamView: View {
    let level: TokenActivityLevel
    let elapsed: TimeInterval
    let state: QuotaDangerState

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            drawStreams(in: &context, size: size)
        }
        .allowsHitTesting(false)
    }

    /// Uses a blurred colored body and a narrow brighter cyan-to-violet core for each stream.
    private func drawStreams(in context: inout GraphicsContext, size: CGSize) {
        let colors = QuotaVisualStyle.dynamicEnergyPalette(for: state)
        let travel = max(level.particleTravelSeconds, 0.1)

        for index in 0..<level.energyRibbonCount {
            let speed = 0.72 + Double(index) * 0.16
            let seed = 0.16 + Double(index) * 0.41
            let phase = (elapsed / travel * speed + seed).truncatingRemainder(dividingBy: 1)
            let centerX = (1 - phase) * size.width
            let lane = level == .active ? 0.30 : (index == 0 ? 0.29 : 0.71)
            let wave = sin(elapsed / travel * .pi * 2 * speed + seed * .pi * 2) * 1.3
            let centerY = size.height * lane + wave
            drawStream(
                in: &context,
                center: CGPoint(x: centerX, y: centerY),
                length: level.streamLength,
                colors: colors,
                coreOpacity: level.streamCoreOpacity,
                glowOpacity: level.streamGlowOpacity,
                coreWidth: level.streamCoreWidth,
                glowWidth: level.streamGlowWidth,
                blur: level.streamBlurRadius
            )
        }

        if level == .veryFast {
            let wakePhase = (elapsed / travel * 0.61 + 0.73).truncatingRemainder(dividingBy: 1)
            drawStream(
                in: &context,
                center: CGPoint(x: (1 - wakePhase) * size.width, y: size.height * 0.71 + 1.8),
                length: level.streamLength * 0.62,
                colors: colors,
                coreOpacity: 0.09,
                glowOpacity: 0.07,
                coreWidth: 1.2,
                glowWidth: 5,
                blur: 7
            )
        }
    }

    /// Draws one curved stream segment with its leading head moving from right to left.
    private func drawStream(
        in context: inout GraphicsContext,
        center: CGPoint,
        length: Double,
        colors: [Color],
        coreOpacity: Double,
        glowOpacity: Double,
        coreWidth: Double,
        glowWidth: Double,
        blur: Double
    ) {
        let tail = CGPoint(x: center.x + length / 2, y: center.y - 1)
        let head = CGPoint(x: center.x - length / 2, y: center.y + 1)
        let path = Path { path in
            path.move(to: tail)
            path.addCurve(
                to: head,
                control1: CGPoint(x: center.x + length * 0.19, y: center.y + 2.2),
                control2: CGPoint(x: center.x - length * 0.19, y: center.y - 2.2)
            )
        }
        let glow = Gradient(colors: [colors[0].opacity(glowOpacity), colors[1].opacity(glowOpacity * 0.78), colors[2].opacity(glowOpacity * 0.65)])
        let core = Gradient(colors: [
            .clear,
            colors[2].opacity(coreOpacity * 0.48),
            colors[1].opacity(coreOpacity * 0.82),
            colors[0].opacity(coreOpacity)
        ])

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: blur))
            layer.stroke(
                path,
                with: .linearGradient(glow, startPoint: tail, endPoint: head),
                style: StrokeStyle(lineWidth: glowWidth, lineCap: .round)
            )
        }
        context.stroke(
            path,
            with: .linearGradient(core, startPoint: tail, endPoint: head),
            style: StrokeStyle(lineWidth: coreWidth, lineCap: .round)
        )
    }
}
