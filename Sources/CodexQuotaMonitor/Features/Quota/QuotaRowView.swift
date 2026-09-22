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
                Spacer()
                Text("\(window.remainingPercent)% 剩余")
                    .font(.subheadline.monospacedDigit().weight(.medium))
            }

            ProgressView(value: Double(window.remainingPercent), total: 100)
                .tint(QuotaFormatter.color(for: window.remainingPercent))

            HStack {
                Text(QuotaFormatter.countdown(to: window.resetsAt))
                Spacer()
                if window.resetsAt != nil {
                    Text(QuotaFormatter.absoluteDate(window.resetsAt))
                        .foregroundStyle(.secondary)
                        .help(QuotaFormatter.absoluteDate(window.resetsAt))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(QuotaFormatter.windowTitle(minutes: window.windowDurationMinutes))，剩余百分之\(window.remainingPercent)，\(QuotaFormatter.countdown(to: window.resetsAt))")
    }
}
