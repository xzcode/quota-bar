import SwiftUI
import CodexQuotaCore

/// Static energy capsule with optional motion driven by recent local token activity.
struct CompactQuotaBar: View {
    let remaining: Int?
    let quotaSummary: String?
    let activityLevel: TokenActivityLevel
    let isStale: Bool
    let isDemoMode: Bool
    let reduceMotion: Bool
    let isHovered: Bool

    private var dangerState: QuotaDangerState {
        QuotaVisualStyle.dangerState(remaining: remaining)
    }

    /// Calm, stale, and Reduce Motion states never construct a TimelineView or particle canvas.
    private var motionLevel: TokenActivityLevel? {
        guard activityLevel != .calm, (!isStale || isDemoMode), !reduceMotion else {
            return nil
        }
        return activityLevel
    }

    var body: some View {
        ZStack {
            StaticEnergyBackground(state: dangerState)
                .saturation(isStale && !isDemoMode ? 0.45 : 1)
                .animation(
                    reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.4),
                    value: isStale && !isDemoMode
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
                .shadow(color: .black.opacity(0.25), radius: 2.5, y: 1)

        }
        .clipShape(Capsule())
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.55), value: dangerState)
        .animation(.easeInOut(duration: 0.22), value: motionLevel)
        .shadow(color: .black.opacity(0.20), radius: 7, y: 3)
        .accessibilityElement(children: .combine)
    }
}
