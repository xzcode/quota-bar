import SwiftUI
import CodexQuotaCore

/// A small native Canvas particle layer for the compact bar.
struct ParticleFlowView: View {
    let level: BurnRateLevel
    let elapsed: TimeInterval
    let reduceMotion: Bool

    var body: some View {
        Canvas { context, size in
            render(in: &context, size: size)
        }
        .allowsHitTesting(false)
    }

    /// Draws static and animated layers from the shared compact-bar clock.
    private func render(in context: inout GraphicsContext, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let isMoving = !reduceMotion && level != .calm
        let travel = max(level.particleTravelSeconds, 0.1)

        drawBackground(in: &context, size: size, isMoving: isMoving, travel: travel)
        guard isMoving else { return }
        drawTrails(in: &context, size: size, travel: travel)
        drawEnergyParticles(in: &context, size: size, travel: travel)
    }

    /// Draws low-opacity background points, which remain fixed in calm mode.
    private func drawBackground(
        in context: inout GraphicsContext,
        size: CGSize,
        isMoving: Bool,
        travel: Double
    ) {
        for index in 0..<level.backgroundParticleCount {
            let seed = Self.unitSeed(index, salt: 17)
            let speed = Self.speedVariation(for: index)
            let phase = isMoving
                ? (elapsed / travel * speed + seed).truncatingRemainder(dividingBy: 1)
                : seed
            let baseY = 0.26 + Self.unitSeed(index, salt: 43) * 0.48
            let amplitude = isMoving ? 0.45 + Double(index % 3) * 0.25 : 0
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

    /// Draws brief trailing points only in the two faster movement tiers.
    private func drawTrails(in context: inout GraphicsContext, size: CGSize, travel: Double) {
        for index in 0..<level.trailCount {
            let speed = Self.speedVariation(for: index + 23)
            let seed = 0.22 + Double(index % level.energyParticleCount) * 0.42
            let phase = (elapsed / travel * speed + seed).truncatingRemainder(dividingBy: 1)
            let leaderX = Self.rightToLeftPosition(for: phase, width: size.width)
            let trailOffset = 2.2 + Double(index % 2) * 1.2
            let x = (leaderX + trailOffset)
                .truncatingRemainder(dividingBy: size.width)
            let y = size.height * (0.38 + Double(index % 3) * 0.12)
            let rect = CGRect(x: x, y: y, width: 3.0, height: 0.85)
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.13)))
        }
    }

    /// Draws the brighter energy points and their subtle halos.
    private func drawEnergyParticles(in context: inout GraphicsContext, size: CGSize, travel: Double) {
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
            context.fill(Path(ellipseIn: halo), with: .color(.white.opacity(0.12)))
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
