import SwiftUI
import CodexQuotaCore

/// Renders one actual primary/secondary window returned by app-server.
struct QuotaRowView: View {
    let window: QuotaWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(QuotaFormatter.windowTitle(minutes: window.windowDurationMinutes))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.94))
                Spacer()
                Text("\(window.remainingPercent)% 剩余")
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(.white.opacity(0.98))
            }

            GeometryReader { geometry in
                let fraction = CGFloat(window.remainingPercent) / 100
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(.white.opacity(0.07))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: QuotaVisualStyle.progressColors(remaining: window.remainingPercent),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * fraction)
                        .shadow(color: QuotaVisualStyle.progressColors(remaining: window.remainingPercent)[0].opacity(0.45), radius: 4)
                    // Fine instrument ticks improve quota estimation without adding numeric clutter.
                    HStack(spacing: 0) {
                        ForEach(0..<10) { _ in
                            Spacer(minLength: 0)
                            Rectangle().fill(.black.opacity(0.28)).frame(width: 1)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(height: 6)
            .accessibilityLabel("剩余额度")
            .accessibilityValue("百分之\(window.remainingPercent)")

            HStack {
                Text(QuotaFormatter.countdown(to: window.resetsAt))
                    .help(QuotaFormatter.absoluteDate(window.resetsAt))
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.63))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(QuotaFormatter.windowTitle(minutes: window.windowDurationMinutes))，剩余百分之\(window.remainingPercent)，\(QuotaFormatter.countdown(to: window.resetsAt))")
    }
}
