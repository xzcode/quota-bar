import SwiftUI
import CodexQuotaCore

/// Composes every moving effect under CompactQuotaBar's single shared TimelineView clock.
struct DynamicEnergyLayer: View {
    let level: TokenActivityLevel
    let elapsed: TimeInterval
    let state: QuotaDangerState

    var body: some View {
        ZStack {
            AuroraStreamView(level: level, elapsed: elapsed, state: state)
            CometFlowView(level: level, elapsed: elapsed, state: state)
        }
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
