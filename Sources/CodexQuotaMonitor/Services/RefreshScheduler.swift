import Foundation

/// Periodic refresh loop with bounded backoff after app-server failures.
@MainActor
final class RefreshScheduler {
    private var task: Task<Void, Never>?

    func start(
        interval: @escaping @MainActor () -> TimeInterval,
        refresh: @escaping @MainActor () async -> Bool
    ) {
        stop()
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            var failureDelay: TimeInterval = 5
            while !Task.isCancelled {
                let succeeded = await refresh()
                let delay = succeeded ? max(5, interval()) : failureDelay
                if !succeeded {
                    failureDelay = min(failureDelay * 3, 60)
                } else {
                    failureDelay = 5
                }

                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    break
                }
            }
            self.task = nil
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
