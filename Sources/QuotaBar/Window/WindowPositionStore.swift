import AppKit

/// Persists only the panel origin so the card returns to its last location.
struct WindowPositionStore {
    private let key = "window.floatingPanelOrigin"

    func load() -> CGPoint? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(PointValue.self, from: data) else {
            return nil
        }
        return CGPoint(x: value.x, y: value.y)
    }

    func save(_ point: CGPoint) {
        let value = PointValue(x: point.x, y: point.y)
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Keeps a restored or resized panel reachable if its previous display was
    /// disconnected or the saved origin was dragged beyond the desktop.
    func visibleOrigin(for origin: CGPoint, size: CGSize) -> CGPoint {
        let savedFrame = CGRect(origin: origin, size: size)
        let screens = NSScreen.screens
        let targetScreen = screens.first(where: { $0.visibleFrame.intersects(savedFrame) })
            ?? NSScreen.main
            ?? screens.first

        guard let visibleFrame = targetScreen?.visibleFrame else { return origin }

        let maxX = max(visibleFrame.minX, visibleFrame.maxX - size.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - size.height)
        return CGPoint(
            x: min(max(origin.x, visibleFrame.minX), maxX),
            y: min(max(origin.y, visibleFrame.minY), maxY)
        )
    }

    private struct PointValue: Codable {
        let x: CGFloat
        let y: CGFloat
    }
}
