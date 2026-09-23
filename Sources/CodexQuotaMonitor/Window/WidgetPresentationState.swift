import CoreGraphics

/// The two persisted presentation sizes of the single desktop widget panel.
enum WidgetPresentationState: String, Equatable, Sendable {
    case collapsed
    case expanded

    /// The compact bar is deliberately short; the expanded card keeps the
    /// existing quota layout height from the first UI implementation.
    var panelSize: CGSize {
        switch self {
        case .collapsed:
            return CGSize(width: 260, height: 24)
        case .expanded:
            return CGSize(width: 330, height: 210)
        }
    }
}
