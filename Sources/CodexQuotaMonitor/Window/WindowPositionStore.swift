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

    private struct PointValue: Codable {
        let x: CGFloat
        let y: CGFloat
    }
}
