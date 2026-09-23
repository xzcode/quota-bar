import CoreGraphics

/// The two persisted presentation sizes of the single desktop widget panel.
enum WidgetPresentationState: String, Equatable, Sendable {
    case collapsed
    case expanded

    /// The compact energy pill stays thick enough to read as a capsule.
    var panelSize: CGSize {
        switch self {
        case .collapsed:
            return CGSize(width: 210, height: 32)
        case .expanded:
            return CGSize(width: 330, height: 210)
        }
    }
}
