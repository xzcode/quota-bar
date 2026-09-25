import SwiftUI
import CodexQuotaCore

/// Composites depth/lane emitters inside one Canvas and the existing shared clock.
struct DynamicEnergyLayer: View {
    let level: TokenActivityLevel
    let elapsed: TimeInterval
    let state: QuotaDangerState

    var body: some View {
        ZStack {
            SoftEnergyGlow(level: level, state: state)
            DenseParticleStreamView(level: level, elapsed: elapsed, state: state)
        }
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
