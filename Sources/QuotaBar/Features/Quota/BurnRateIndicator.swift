import SwiftUI
import CodexQuotaCore

/// Human-readable burn-rate status for the expanded card.
struct BurnRateIndicator: View {
    let snapshot: BurnRateSnapshot

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "speedometer")
                .font(.caption2)
            Text("消耗速度：\(snapshot.level.label)")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.54))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("消耗速度：\(snapshot.level.label)")
    }
}
