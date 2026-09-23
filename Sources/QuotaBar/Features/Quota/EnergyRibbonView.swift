import SwiftUI
import CodexQuotaCore

/// Draws one or two soft curved energy strands using the compact bar's shared clock.
struct EnergyRibbonView: View {
    let level: BurnRateLevel
    let elapsed: TimeInterval
    let state: QuotaDangerState

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            drawRibbons(in: &context, size: size)
        }
        .allowsHitTesting(false)
    }

    /// Keeps every ribbon moving right-to-left with a dim trailing side and brighter leading tip.
    private func drawRibbons(in context: inout GraphicsContext, size: CGSize) {
        let palette = QuotaVisualStyle.palette(for: state)
        let travel = max(level.particleTravelSeconds, 0.1)
        let count = level.energyRibbonCount

        for index in 0..<count {
            let speed = 0.72 + Double(index) * 0.16
            let seed = 0.18 + Double(index) * 0.43
            let phase = (elapsed / travel * speed + seed).truncatingRemainder(dividingBy: 1)
            let centerX = (1 - phase) * size.width
            let centerY = count == 1
                ? size.height * 0.5
                : size.height * (index == 0 ? 0.35 : 0.65)
            let length = level == .active ? 58.0 : (level == .fast ? 72.0 : 86.0)
            let wave = sin(elapsed / travel * .pi * 2 * speed + seed * .pi * 2) * 1.25
            let tail = CGPoint(x: centerX + length / 2, y: centerY - wave)
            let head = CGPoint(x: centerX - length / 2, y: centerY + wave)
            let path = Path { path in
                path.move(to: tail)
                path.addCurve(
                    to: head,
                    control1: CGPoint(x: centerX + length * 0.18, y: centerY + wave * 1.8),
                    control2: CGPoint(x: centerX - length * 0.18, y: centerY - wave * 1.8)
                )
            }
            let opacity = level == .active ? 0.18 : (level == .fast ? 0.25 : 0.32)

            context.drawLayer { glow in
                glow.addFilter(.blur(radius: level == .active ? 3 : 4))
                glow.stroke(
                    path,
                    with: .color(palette[1].opacity(opacity)),
                    style: StrokeStyle(lineWidth: level == .active ? 4 : 5, lineCap: .round)
                )
            }

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [.clear, palette[1].opacity(opacity), .white.opacity(opacity * 0.85)]),
                    startPoint: tail,
                    endPoint: head
                ),
                style: StrokeStyle(lineWidth: level == .active ? 1.2 : 1.7, lineCap: .round)
            )
        }
    }
}
