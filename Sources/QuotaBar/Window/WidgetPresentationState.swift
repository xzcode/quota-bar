import CoreGraphics

/// The two persisted presentation sizes of the single desktop widget panel.
enum WidgetPresentationState: String, Equatable, Sendable {
    case collapsed
    case expanded

    /// The compact energy pill is shorter than the expanded card by design.
    var panelSize: CGSize {
        switch self {
        case .collapsed:
            return CGSize(width: 240, height: 28)
        case .expanded:
            return CGSize(width: 330, height: 210)
        }
    }
}
