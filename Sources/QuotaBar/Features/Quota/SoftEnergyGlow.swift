import SwiftUI
import CodexQuotaCore

/// Adds only a blurred, low-opacity ambience behind the discrete particle stream.
struct SoftEnergyGlow: View {
    let level: TokenActivityLevel
    let state: QuotaDangerState

    var body: some View {
        GeometryReader { geometry in
            let colors = QuotaVisualStyle.softEnergyParticlePalette(for: state)
            let violetAccent = QuotaVisualStyle.activityVioletAccent(for: state)

            ZStack {
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

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [violetAccent.opacity(0.92), violetAccent.opacity(0.42), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geometry.size.width * 0.22
                        )
                    )
                    .frame(width: geometry.size.width * 0.44, height: geometry.size.height * 1.5)
                    .blur(radius: 15)
                    .opacity(level.rightVioletAccent)
                    .position(x: geometry.size.width * 0.89, y: geometry.size.height / 2)
                    .animation(.easeInOut(duration: 0.55), value: level)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
