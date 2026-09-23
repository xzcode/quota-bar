import SwiftUI
import CodexQuotaCore

/// A small native Canvas particle layer for the compact bar.
struct ParticleFlowView: View {
    let level: BurnRateLevel
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                guard size.width > 0, size.height > 0 else { return }
                let now = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let travel = level.particleTravelSeconds

                for index in 0..<level.particleCount {
                    let seed = Double(index) * 0.61803398875
                    let phase = reduceMotion
                        ? 0.14 + seed.truncatingRemainder(dividingBy: 0.72)
                        : (now / travel + seed).truncatingRemainder(dividingBy: 1)
                    let x = phase * size.width
                    let wave = sin(now / travel * .pi * 2 + seed * .pi * 4)
                    let y = size.height * (0.36 + 0.28 * wave)
                    let diameter = 1.0 + (Double(index % 3) * 0.65)
                    let opacity = min(0.85, (0.28 + (Double(index % 4) * 0.12)) * level.particleOpacityMultiplier)
                    let rect = CGRect(
                        x: x - diameter / 2,
                        y: y - diameter / 2,
                        width: diameter,
                        height: diameter
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
