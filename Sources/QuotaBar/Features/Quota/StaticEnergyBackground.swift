import SwiftUI

/// A fully static glass-and-energy finish for calm and Reduce Motion states.
struct StaticEnergyBackground: View {
    let state: QuotaDangerState

    private var palette: [Color] {
        QuotaVisualStyle.palette(for: state)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: palette,
                    startPoint: .leading,
                    endPoint: .trailing
                )

                // Broad blurred radial overlays keep the capsule dimensional without hard circles.
                RadialGradient(
                    colors: [palette[0].opacity(0.30), palette[0].opacity(0)],
                    center: UnitPoint(x: 0.04, y: 0.5),
                    startRadius: 1,
                    endRadius: geometry.size.width * 0.62
                )
                .blur(radius: 16)

                RadialGradient(
                    colors: [palette[palette.count - 1].opacity(0.24), palette[palette.count - 1].opacity(0)],
                    center: UnitPoint(x: 0.97, y: 0.5),
                    startRadius: 1,
                    endRadius: geometry.size.width * 0.58
                )
                .blur(radius: 16)

                RadialGradient(
                    colors: [.white.opacity(0.075), .white.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.42
                )
                .blur(radius: 12)

                LinearGradient(
                    colors: [.white.opacity(0.07), .clear, .black.opacity(0.10)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.16), .white.opacity(0.12), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1.4)
                    .padding(.horizontal, 22)
                    .padding(.top, 1)
                    Spacer(minLength: 0)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [palette[0].opacity(0.42), palette[1].opacity(0.28), palette.last!.opacity(0.38)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            }
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.045), lineWidth: 0.55)
                    .padding(1)
            }
        }
        .accessibilityHidden(true)
    }
}
