import SwiftUI
import CodexQuotaCore

/// The compact quota summary with a gentle animated flow.
struct CompactQuotaBar: View {
    let remaining: Int?
    let quotaSummary: String?
    let burnRate: BurnRateSnapshot
    let isParticlePulseActive: Bool
    let isStale: Bool
    let reduceMotion: Bool
    let isHovered: Bool
    @State private var animatedRemaining = 100.0
    @State private var hasInitialPalette = false

    var body: some View {
        ZStack {
            animatedFlow

            Text(quotaSummary ?? remaining.map { "\($0)%" } ?? "—")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)
                .shadow(color: .black.opacity(0.22), radius: 2, y: 1)

            if isStale {
                Circle()
                    .fill(.orange)
                    .frame(width: 5, height: 5)
                    .shadow(color: .black.opacity(0.25), radius: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 8)
            }
        }
        .clipShape(Capsule())
        .saturation(isStale ? 0.45 : 1)
        .animation(
            reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.4),
            value: isStale
        )
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 10, y: 4)
        .onAppear {
            setInitialPaletteIfNeeded()
        }
        .onChange(of: remaining) { _, newValue in
            guard let newValue else { return }
            guard hasInitialPalette else {
                animatedRemaining = Double(newValue)
                hasInitialPalette = true
                return
            }

            let duration = reduceMotion ? 0.12 : 0.65
            withAnimation(.easeInOut(duration: duration)) {
                animatedRemaining = Double(newValue)
            }
        }
    }

    /// Uses one shared clock for both gradient flow and particles; calm renders once.
    @ViewBuilder
    private var animatedFlow: some View {
        if !reduceMotion, let interval = motionLevel.animationFrameInterval {
            TimelineView(.animation(minimumInterval: interval, paused: false)) { timeline in
                flowLayers(elapsed: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            flowLayers(elapsed: 0)
        }
    }

    private func flowLayers(elapsed: TimeInterval) -> some View {
        let phase = (elapsed * motionLevel.gradientSpeed).truncatingRemainder(dividingBy: 1)
        let paletteRemaining = remaining == nil ? nil : animatedRemaining
        let colors = QuotaVisualStyle.gradientColors(remaining: paletteRemaining, isStale: isStale)

        return ZStack {
            LinearGradient(
                colors: colors,
                startPoint: UnitPoint(x: -0.35 + phase, y: 0),
                endPoint: UnitPoint(x: 1.05 + phase, y: 1)
            )
            ParticleFlowView(level: motionLevel, elapsed: elapsed, reduceMotion: reduceMotion)
                .opacity(isHovered ? 1 : 0.78)
        }
    }

    /// Retains the quota color on first appearance so its initial render does not animate.
    private func setInitialPaletteIfNeeded() {
        guard !hasInitialPalette, let remaining else { return }
        animatedRemaining = Double(remaining)
        hasInitialPalette = true
    }

    /// Motion is a short response to a fresh usage increase, not the whole rolling rate window.
    private var motionLevel: BurnRateLevel {
        guard isParticlePulseActive, !isStale else { return .calm }
        return burnRate.level == .calm ? .active : burnRate.level
    }
}
