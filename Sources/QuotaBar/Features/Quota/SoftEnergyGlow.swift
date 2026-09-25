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
                            endRadius: min(26, max(14, geometry.size.width * 0.06))
                        )
                    )
                    .frame(width: min(76, max(44, geometry.size.width * 0.15)), height: geometry.size.height * 1.5)
                    .blur(radius: 15)
                    .opacity(level.rightVioletAccent)
                    .position(x: geometry.size.width * 0.89, y: geometry.size.height / 2)
                    .animation(.easeInOut(duration: 0.55), value: level)

                // This right-edge wash makes the activity-dependent violet visible in a still frame.
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: violetAccent.opacity(0.08), location: 0.45),
                        .init(color: violetAccent.opacity(0.28), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 0.35, height: geometry.size.height)
                .opacity(level.rightVioletOverlayOpacity)
                .position(x: geometry.size.width * 0.825, y: geometry.size.height / 2)
                .animation(.easeInOut(duration: 0.55), value: level)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
