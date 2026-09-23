import SwiftUI
import CodexQuotaCore

/// Composes all moving effects under the single TimelineView owned by CompactQuotaBar.
struct DynamicEnergyLayer: View {
    let level: TokenActivityLevel
    let elapsed: TimeInterval
    let state: QuotaDangerState

    var body: some View {
        ZStack {
            EnergyRibbonView(level: level, elapsed: elapsed, state: state)
            movingHighlight
            ParticleFlowView(level: level, elapsed: elapsed, state: state)
        }
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A soft narrow band sweeps in the same direction as ribbons and particles.
    private var movingHighlight: some View {
        GeometryReader { geometry in
            let travel = max(level.particleTravelSeconds, 0.1)
            let phase = (elapsed / travel * 0.62 + 0.37).truncatingRemainder(dividingBy: 1)
            let centerX = (1 - phase) * geometry.size.width
            let width = level.movingHighlightWidth

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(level.movingHighlightOpacity * 0.3),
                            .white.opacity(level.movingHighlightOpacity),
                            .white.opacity(level.movingHighlightOpacity * 0.25),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: geometry.size.height + 4)
                .blur(radius: level == .active ? 5 : 7)
                .position(x: centerX, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false)
    }
}
