import SwiftUI
import CodexQuotaCore

/// Shows real local token activity next to today's aggregate on the expanded card.
struct LocalTokenUsageIndicator: View {
    let snapshot: LocalTokenUsageSnapshot
    let tooltipText: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "speedometer")
                .font(.caption2)
            Text(snapshot.activityLevel.label)
            Spacer()
            Text(todayUsageText)
                .help(tooltipText)
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.54))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("本机 Token 活动：\(snapshot.activityLevel.label)，\(todayUsageText)")
    }

    private var todayUsageText: String {
        snapshot.isAvailable ? "今日 \(LocalTokenUsageFormatter.format(snapshot.todayTotalTokens))" : "今日 —"
    }
}
