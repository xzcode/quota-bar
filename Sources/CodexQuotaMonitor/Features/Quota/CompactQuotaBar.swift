import SwiftUI
import CodexQuotaCore

/// The compact quota summary with a gentle animated flow.
struct CompactQuotaBar: View {
    let remaining: Int?
    let quotaSummary: String?
    let burnRate: BurnRateSnapshot
    let isStale: Bool
    let reduceMotion: Bool
    let isHovered: Bool

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let phase = (elapsed * burnRate.level.gradientSpeed).truncatingRemainder(dividingBy: 1)
                let colors = QuotaVisualStyle.gradientColors(remaining: remaining, isStale: isStale)

                LinearGradient(
                    colors: colors,
                    startPoint: UnitPoint(x: -0.35 + phase, y: 0),
                    endPoint: UnitPoint(x: 1.05 + phase, y: 1)
                )
            }
            ParticleFlowView(level: burnRate.level, reduceMotion: reduceMotion)
                .opacity(isHovered ? 1 : 0.78)

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
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 10, y: 4)
    }
}
