import SwiftUI
import CodexQuotaCore

/// Draws restrained straight energy ribbons along the upper and lower fixed lanes.
struct AuroraStreamView: View {
    let level: TokenActivityLevel
    let elapsed: TimeInterval
    let state: QuotaDangerState

    private let laneY: [CGFloat] = [7, 12, 20, 25]
    private let phaseOffsets = [0.17, 0.63]
    private let speedOffsets = [-0.10, 0.11]

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0, level != .calm else { return }
            drawStreams(in: &context, size: size)
        }
        .allowsHitTesting(false)
    }

    /// Moves each fixed-length horizontal ribbon through the capsule with a stable phase and speed.
    private func drawStreams(in context: inout GraphicsContext, size: CGSize) {
        let colors = QuotaVisualStyle.dynamicEnergyPalette(for: state)
        let margin = CGFloat(level.streamLength) / 2 + 10
        let travelDistance = size.width + margin * 2

        for index in 0..<level.energyRibbonCount {
            let rawPhase = elapsed / max(level.particleTravelSeconds, 0.1) * (1 + speedOffsets[index]) + phaseOffsets[index]
            let phase = rawPhase - floor(rawPhase)
            let centerX = size.width + margin - CGFloat(phase) * travelDistance
            let lane = level == .active ? 0 : (index == 0 ? 0 : 3)
            let y = laneY[lane]
            let textOpacity = centerX >= 40 && centerX <= 170 ? 0.45 : 1
            let tail = CGPoint(x: centerX + level.streamLength / 2, y: y)
            let head = CGPoint(x: centerX - level.streamLength / 2, y: y)
            drawStream(
                in: &context,
                tail: tail,
                head: head,
                colors: colors,
                coreOpacity: level.streamCoreOpacity * textOpacity,
                glowOpacity: level.streamGlowOpacity * textOpacity,
                coreWidth: level.streamCoreWidth,
                glowWidth: level.streamGlowWidth,
                blur: level.streamBlurRadius
            )
        }
    }

    /// Draws a linear, colored tail with no curve or time-varying vertical position.
    private func drawStream(
        in context: inout GraphicsContext,
        tail: CGPoint,
        head: CGPoint,
        colors: [Color],
        coreOpacity: Double,
        glowOpacity: Double,
        coreWidth: Double,
        glowWidth: Double,
        blur: Double
    ) {
        let path = Path { path in
            path.move(to: tail)
            path.addLine(to: head)
        }
        let glow = Gradient(colors: [
            colors[2].opacity(glowOpacity * 0.58),
            colors[1].opacity(glowOpacity * 0.82),
            colors[0].opacity(glowOpacity)
        ])
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
