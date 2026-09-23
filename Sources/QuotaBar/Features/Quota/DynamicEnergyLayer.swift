import SwiftUI
import CodexQuotaCore

/// Composes every V2 FX layer under CompactQuotaBar's single shared TimelineView clock.
struct DynamicEnergyLayer: View {
    let level: TokenActivityLevel
    let elapsed: TimeInterval
    let state: QuotaDangerState

    var body: some View {
        ZStack {
            AuroraStreamView(level: level, elapsed: elapsed, state: state)
            CometFlowView(level: level, elapsed: elapsed, state: state)
            sweepLight
            if level == .fast || level == .veryFast {
                textSafeZoneVignette
            }
            if level.edgeStreakWidth > 0 {
                edgeEnergyStreak
            }
        }
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A diagonal cyan-to-violet beam sweeps across the capsule using the shared elapsed time.
    private var sweepLight: some View {
        GeometryReader { geometry in
            let travel = max(level.particleTravelSeconds, 0.1)
            let phase = (elapsed / travel * 0.72 + 0.37).truncatingRemainder(dividingBy: 1)
            let centerX = (1 - phase) * geometry.size.width
            let width = level.sweepWidth

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: QuotaVisualStyle.dynamicEnergyPalette(for: state)[0].opacity(0.52), location: 0.34),
                    .init(color: .white.opacity(0.16), location: 0.48),
                    .init(color: QuotaVisualStyle.dynamicEnergyPalette(for: state)[2].opacity(0.68), location: 0.64),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
                .frame(width: width, height: geometry.size.height + 18)
                .rotationEffect(.degrees(14))
                .blur(radius: 8)
                .opacity(level.sweepOpacity)
                .position(x: centerX, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false)
    }

    /// Slightly lowers moving contrast behind the centered quota string at higher activity.
    private var textSafeZoneVignette: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [.clear, .black.opacity(0.075), .black.opacity(0.075), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 100, height: geometry.size.height)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false)
    }

    /// Adds a moving cyan highlight along only the top edge at fast and very-fast activity.
    private var edgeEnergyStreak: some View {
        Canvas { context, size in
            let width = level.edgeStreakWidth
            guard width > 0, size.width > 0 else { return }
            let travel = max(level.particleTravelSeconds, 0.1)
            let phase = (elapsed / travel * 1.18 + 0.19).truncatingRemainder(dividingBy: 1)
            let x = (1 - phase) * (size.width + width) - width
            let start = CGPoint(x: x + width, y: 1.7)
            let end = CGPoint(x: x, y: 1.7)
            let path = Path { path in
                path.move(to: start)
                path.addLine(to: end)
            }
            let cyan = QuotaVisualStyle.dynamicEnergyPalette(for: state)[0]
            let streak = Gradient(colors: [cyan.opacity(0.12 * level.edgeStreakOpacity), cyan.opacity(level.edgeStreakOpacity), .clear])

            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 3))
                glow.stroke(
                    path,
                    with: .linearGradient(streak, startPoint: start, endPoint: end),
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                )
            }
            context.stroke(
                path,
                with: .linearGradient(streak, startPoint: start, endPoint: end),
                style: StrokeStyle(lineWidth: 1.1, lineCap: .round)
            )
        }
        .allowsHitTesting(false)
    }
}
