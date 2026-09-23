import SwiftUI
import CodexQuotaCore

/// Static energy capsule with a pulse-only animated layer for recent usage.
struct CompactQuotaBar: View {
    let remaining: Int?
    let quotaSummary: String?
    let burnRate: BurnRateSnapshot
    let isParticlePulseActive: Bool
    let isStale: Bool
    let reduceMotion: Bool
    let isHovered: Bool

    private var dangerState: QuotaDangerState {
        QuotaVisualStyle.dangerState(remaining: remaining)
    }

    /// Calm, stale, and Reduce Motion states never construct a TimelineView or particle canvas.
    private var motionLevel: BurnRateLevel? {
        guard isParticlePulseActive,
              !isStale,
              !reduceMotion,
              burnRate.level != .calm else {
            return nil
        }
        return burnRate.level
    }

    var body: some View {
        ZStack {
            StaticEnergyBackground(state: dangerState)
                .saturation(isStale ? 0.45 : 1)
                .animation(
                    reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.4),
                    value: isStale
                )

            if let motionLevel, let interval = motionLevel.animationFrameInterval {
                TimelineView(.animation(minimumInterval: interval, paused: false)) { timeline in
                    DynamicEnergyLayer(
                        level: motionLevel,
                        elapsed: timeline.date.timeIntervalSinceReferenceDate,
                        state: dangerState
                    )
                    .saturation(isStale ? 0.45 : 1)
                }
                .transition(.opacity)
            }

            Text(quotaSummary ?? remaining.map { "\($0)%" } ?? "—")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
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
                    .padding(.leading, 9)
            }
        }
        .clipShape(Capsule())
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.55), value: dangerState)
        .animation(.easeInOut(duration: 0.22), value: motionLevel)
        .shadow(color: .black.opacity(0.20), radius: 7, y: 3)
        .accessibilityElement(children: .combine)
    }
}
