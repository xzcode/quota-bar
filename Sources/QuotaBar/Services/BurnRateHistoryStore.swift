import Foundation
import CodexQuotaCore

/// Couples the rolling burn-rate estimate with a newly observed usage change.
struct BurnRateUpdate {
    let snapshot: BurnRateSnapshot
    let didIncreaseUsage: Bool
}

/// Persists a small, credential-free history used only for local animation.
struct BurnRateHistoryStore {
    private static let storageKey = "cache.burnRateHistory.v1"
    private static let retention: TimeInterval = 60 * 60
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Records the most dangerous visible window and returns its current rate.
    mutating func record(snapshot: QuotaSnapshot, previousSnapshot: QuotaSnapshot?) -> BurnRateUpdate {
        guard let selected = selectedWindow(in: snapshot) else {
            return BurnRateUpdate(snapshot: .unknown, didIncreaseUsage: false)
        }

        var records = load()
        let sameWindow = records
            .filter { matches($0, bucketId: selected.bucketId, kind: selected.window.kind) }
            .sorted { $0.sample.timestamp < $1.sample.timestamp }

        if let previous = sameWindow.last, indicatesReset(previous: previous, current: selected.window) {
            // Keep other bucket/window histories, but start this window fresh.
            records.removeAll {
                matches($0, bucketId: selected.bucketId, kind: selected.window.kind)
            }
        }

        records.append(StoredUsageSample(
            sample: QuotaUsageSample(
                timestamp: snapshot.capturedAt,
                bucketId: selected.bucketId,
                windowKind: selected.window.kind,
                usedPercent: selected.window.usedPercent
            ),
            resetsAt: selected.window.resetsAt
        ))
        records = records.filter {
            $0.sample.timestamp >= snapshot.capturedAt.addingTimeInterval(-Self.retention)
        }
        save(records)

        let samples = records
            .filter { matches($0, bucketId: selected.bucketId, kind: selected.window.kind) }
            .map(\.sample)
        return BurnRateUpdate(
            snapshot: BurnRateCalculator.calculate(samples: samples, now: snapshot.capturedAt),
            didIncreaseUsage: observedUsageIncrease(from: previousSnapshot, to: snapshot)
        )
    }

    /// Reconstructs a rate after restart without inventing a new sample.
    func current(for snapshot: QuotaSnapshot?) -> BurnRateSnapshot {
        guard let snapshot, let selected = selectedWindow(in: snapshot) else {
            return .unknown
        }
        let samples = load()
            .filter { matches($0, bucketId: selected.bucketId, kind: selected.window.kind) }
            .map(\.sample)
        return BurnRateCalculator.calculate(samples: samples, now: snapshot.capturedAt)
    }

    private func load() -> [StoredUsageSample] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let records = try? JSONDecoder().decode([StoredUsageSample].self, from: data) else {
            return []
        }
        return records
    }

    private func save(_ records: [StoredUsageSample]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func selectedWindow(in snapshot: QuotaSnapshot) -> (bucketId: String, window: QuotaWindow)? {
        let bucket = snapshot.buckets.first(where: { $0.id == "codex" }) ?? snapshot.buckets.first
        guard let bucket, let window = bucket.windows.min(by: { $0.remainingPercent < $1.remainingPercent }) else {
            return nil
        }
        return (bucket.id, window)
    }

    private func matches(_ record: StoredUsageSample, bucketId: String, kind: QuotaWindow.WindowKind) -> Bool {
        record.sample.bucketId == bucketId && record.sample.windowKind == kind
    }

    private func indicatesReset(previous: StoredUsageSample, current: QuotaWindow) -> Bool {
        if let oldReset = previous.resetsAt, let newReset = current.resetsAt,
           abs(oldReset.timeIntervalSince(newReset)) > 60 {
            return true
        }

        // A meaningful drop in used percent is a reset, not negative burn.
        return current.usedPercent <= previous.sample.usedPercent - 10
    }

    /// Compares adjacent successful snapshots only, ignoring old cached usage deltas.
    private func observedUsageIncrease(from previous: QuotaSnapshot?, to current: QuotaSnapshot) -> Bool {
        guard let previous else { return false }
        let elapsed = current.capturedAt.timeIntervalSince(previous.capturedAt)
        guard elapsed >= 0, elapsed <= 10 * 60 else { return false }

        return current.buckets.contains { currentBucket in
            guard let previousBucket = previous.buckets.first(where: { $0.id == currentBucket.id }) else {
                return false
            }

            return currentBucket.windows.contains { currentWindow in
                guard let previousWindow = previousBucket.windows.first(where: {
                    $0.id == currentWindow.id && $0.windowDurationMinutes == currentWindow.windowDurationMinutes
                }) else {
                    return false
                }

                if let oldReset = previousWindow.resetsAt,
                   let newReset = currentWindow.resetsAt,
                   abs(oldReset.timeIntervalSince(newReset)) > 60 {
                    return false
                }
                return currentWindow.usedPercent > previousWindow.usedPercent
            }
        }
    }
}

/// Adds reset metadata to the otherwise public usage sample without storing
/// any authentication or account information.
private struct StoredUsageSample: Codable, Sendable {
    let sample: QuotaUsageSample
    let resetsAt: Date?
}
