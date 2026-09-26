import SwiftUI

/// A continuous illuminated glass surface stays motionless when usage stops.
struct StaticEnergyBackground: View {
    let state: QuotaDangerState

    var body: some View {
        GeometryReader { geometry in
            let colors = QuotaVisualStyle.softEnergyParticlePalette(for: state)
            ZStack {
                LinearGradient(
                    // Restore the original saturated blue-violet surface, including quota danger palettes.
                    colors: QuotaVisualStyle.palette(for: state),
                    startPoint: .leading, endPoint: .trailing
                )
                RadialGradient(
                    colors: [colors[0].opacity(0.22), colors[0].opacity(0.04), .clear],
                    center: UnitPoint(x: 0.02, y: 0.85), startRadius: 0,
                    endRadius: geometry.size.width * 0.72
                )
                RadialGradient(
                    colors: [colors[2].opacity(0.22), colors[2].opacity(0.04), .clear],
                    center: UnitPoint(x: 0.98, y: 0.2), startRadius: 0,
                    endRadius: geometry.size.width * 0.70
                )
                // A faint reflection preserves saturated color instead of washing the surface gray.
                LinearGradient(colors: [.white.opacity(0.035), .clear],
                               startPoint: .top, endPoint: .bottom)
            }
            .clipShape(Capsule())
            .overlay {
                Capsule().strokeBorder(
                    LinearGradient(colors: [colors[0].opacity(0.8), .white.opacity(0.22),
                                            colors[2].opacity(0.55), colors[0].opacity(0.22)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.8
                )
            }
            .overlay {
                Capsule().inset(by: 2).strokeBorder(.white.opacity(0.05), lineWidth: 0.5)
            }
        }
        .accessibilityHidden(true)
    }
}
