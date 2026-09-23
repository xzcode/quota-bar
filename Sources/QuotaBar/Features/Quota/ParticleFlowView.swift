import SwiftUI
import CodexQuotaCore

/// Dynamic-only particles, energy cores, and faded comet trails for the compact bar.
struct ParticleFlowView: View {
    let level: TokenActivityLevel
    let elapsed: TimeInterval
    let state: QuotaDangerState

    var body: some View {
        Canvas { context, size in
            render(in: &context, size: size)
        }
        .allowsHitTesting(false)
    }

    /// Draws every dynamic particle layer from the shared compact-bar clock.
    private func render(in context: inout GraphicsContext, size: CGSize) {
        guard size.width > 0, size.height > 0, level != .calm else { return }
        let travel = max(level.particleTravelSeconds, 0.1)

        drawBackground(in: &context, size: size, travel: travel)
        drawTrails(in: &context, size: size, travel: travel)
        drawEnergyParticles(in: &context, size: size, travel: travel)
    }

    /// Draws subdued background flow points that only exist while the dynamic layer is mounted.
    private func drawBackground(
        in context: inout GraphicsContext,
        size: CGSize,
        travel: Double
    ) {
        for index in 0..<level.backgroundParticleCount {
            let seed = Self.unitSeed(index, salt: 17)
            let speed = Self.speedVariation(for: index)
            let phase = (elapsed / travel * speed + seed).truncatingRemainder(dividingBy: 1)
            let baseY = 0.26 + Self.unitSeed(index, salt: 43) * 0.48
            let amplitude = 0.45 + Double(index % 3) * 0.25
            let wave = sin(elapsed / travel * .pi * 2 * speed + seed * .pi * 4) * amplitude
            let diameter = 0.9 + Double(index % 4) * 0.28
            let opacity = (0.16 + Double(index % 4) * 0.045) * level.particleOpacityMultiplier
            let rect = CGRect(
                x: Self.rightToLeftPosition(for: phase, width: size.width) - diameter / 2,
                y: baseY * size.height + wave - diameter / 2,
                width: diameter,
                height: diameter
            )
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
        }
    }

    /// Draws transparent-to-bright stroked comets, with their tails trailing to the right.
    private func drawTrails(in context: inout GraphicsContext, size: CGSize, travel: Double) {
        let palette = QuotaVisualStyle.palette(for: state)
        for index in 0..<level.trailCount {
            let particleIndex = index % level.energyParticleCount
            let seed = 0.18 + Double(particleIndex) * 0.46
            let speed = Self.speedVariation(for: particleIndex + 37)
            let phase = (elapsed / travel * speed + seed).truncatingRemainder(dividingBy: 1)
            let leaderX = Self.rightToLeftPosition(for: phase, width: size.width)
            let wave = sin(elapsed / travel * .pi * 2 * speed + seed * .pi * 4)
            let y = size.height * (0.48 + 0.08 * wave)
            let trailLength = level.cometTrailLength
            let tail = CGPoint(x: leaderX + trailLength, y: y)
            let head = CGPoint(x: leaderX, y: y)
            let path = Path { path in
                path.move(to: tail)
                path.addLine(to: head)
            }
            let opacity = level == .fast ? 0.32 : 0.42

            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 1.8))
                glow.stroke(
                    path,
                    with: .color(palette[1].opacity(opacity * 0.55)),
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                )
            }
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [.clear, palette[1].opacity(opacity), .white.opacity(opacity)]),
                    startPoint: tail,
                    endPoint: head
                ),
                style: StrokeStyle(lineWidth: 1.7, lineCap: .round)
            )
        }
    }

    /// Draws the brighter energy points and their subtle halos.
    private func drawEnergyParticles(in context: inout GraphicsContext, size: CGSize, travel: Double) {
        let palette = QuotaVisualStyle.palette(for: state)
        for index in 0..<level.energyParticleCount {
            let seed = 0.18 + Double(index) * 0.46
            let speed = Self.speedVariation(for: index + 37)
            let phase = (elapsed / travel * speed + seed).truncatingRemainder(dividingBy: 1)
            let wave = sin(elapsed / travel * .pi * 2 * speed + seed * .pi * 4)
            let x = Self.rightToLeftPosition(for: phase, width: size.width)
            let y = size.height * (0.48 + 0.08 * wave)
            let diameter = level == .active ? 2.2 : (level == .fast ? 2.6 : 3.0)
            let halo = CGRect(
                x: x - (diameter + 2.2) / 2,
                y: y - (diameter + 2.2) / 2,
                width: diameter + 2.2,
                height: diameter + 2.2
            )
            let core = CGRect(
                x: x - diameter / 2,
                y: y - diameter / 2,
                width: diameter,
                height: diameter
            )
            context.fill(Path(ellipseIn: halo), with: .color(palette[1].opacity(0.32)))
            context.fill(Path(ellipseIn: core), with: .color(.white.opacity(0.92)))
        }
    }

    /// Returns a repeatable [0, 1) coordinate without allocating random state per frame.
    private static func unitSeed(_ index: Int, salt: Int) -> Double {
        Double((index * 37 + salt * 19) % 101) / 101
    }

    /// Varies particle speed deterministically by up to twenty percent.
    private static func speedVariation(for index: Int) -> Double {
        0.8 + Double((index * 7 + 3) % 21) * 0.02
    }

    /// Maps an advancing phase to the right-to-left horizontal travel direction.
    private static func rightToLeftPosition(for phase: Double, width: CGFloat) -> CGFloat {
        (1 - phase) * width
    }
}
