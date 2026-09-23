import SwiftUI
import CodexQuotaCore

/// Adds only a blurred, low-opacity ambience behind the discrete particle stream.
struct SoftEnergyGlow: View {
    let level: TokenActivityLevel
    let state: QuotaDangerState

    var body: some View {
        GeometryReader { geometry in
            let colors = QuotaVisualStyle.softEnergyParticlePalette(for: state)
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [colors[0].opacity(0.72), colors[2].opacity(0.42), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 42
                    )
                )
                .frame(width: 84, height: geometry.size.height)
                .blur(radius: 15)
                .opacity(level.softEnergyGlowOpacity)
                .position(x: geometry.size.width * 0.32, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
