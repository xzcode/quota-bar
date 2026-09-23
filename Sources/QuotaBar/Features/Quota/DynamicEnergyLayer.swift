import SwiftUI
import CodexQuotaCore

/// Keeps the compact motion to one soft glow and one Canvas particle stream.
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
