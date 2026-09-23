import Foundation
import CodexQuotaCore

/// Background actor that discovers candidate rollouts once and tails only token statistics.
actor LocalTokenUsageMonitor {
    private struct RolloutTailState {
        let url: URL
        let sessionStartedAt: Date?
        var byteOffset: UInt64 = 0
        var lineBuffer = JSONLLineBuffer()
        var fileSize: UInt64 = 0
        var modificationDate = Date.distantPast
    }

    private let sessionsDirectory: URL
    private let calendar: Calendar
    private var accumulator = LocalTokenUsageAccumulator()
    private var tailStates: [String: RolloutTailState] = [:]
    private var lastDiscoveryAt = Date.distantPast
    private var currentDayStart: Date?
    private let discoveryInterval: TimeInterval = 12
    private let maximumFilesPerPoll = 64

    init(sessionsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions", isDirectory: true), calendar: Calendar = .current) {
        self.sessionsDirectory = sessionsDirectory
        self.calendar = calendar
    }

    /// Performs the one startup history discovery so ongoing sessions restore activity immediately.
    func start(now: Date = .now) -> LocalTokenUsageSnapshot {
        currentDayStart = calendar.startOfDay(for: now)
        discoverRollouts(now: now)
        lastDiscoveryAt = now
        return accumulator.snapshot(now: now, calendar: calendar)
    }

    /// Polls recent candidate files and occasionally discovers new or newly active rollouts.
    func poll(now: Date = .now) -> LocalTokenUsageSnapshot {
        let dayStart = calendar.startOfDay(for: now)
        if dayStart != currentDayStart {
            currentDayStart = dayStart
            // Prior-day candidates are rebuilt below, releasing stale per-file tail state.
            tailStates.removeAll(keepingCapacity: true)
            accumulator = LocalTokenUsageAccumulator()
            // A once-daily metadata rescan finds older sessions that resumed after midnight.
            discoverRollouts(now: now)
            lastDiscoveryAt = now
        } else if now.timeIntervalSince(lastDiscoveryAt) >= discoveryInterval {
            discoverRollouts(now: now)
            lastDiscoveryAt = now
        }

        pollRecentFiles()
        return accumulator.snapshot(now: now, calendar: calendar)
    }

    /// Finds today's/yesterday's sessions and older rollouts modified since local midnight.
    private func discoverRollouts(now: Date) {
        let todayStart = calendar.startOfDay(for: now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        guard FileManager.default.fileExists(atPath: sessionsDirectory.path),
              let enumerator = FileManager.default.enumerator(
                at: sessionsDirectory,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
              ) else { return }

        for case let url as URL in enumerator {
            guard isRolloutFile(url), let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { continue }
            let modifiedAt = attributes[.modificationDate] as? Date ?? .distantPast
            let sessionDate = sessionStartDate(for: url)
            let isRecentSession = sessionDate.map { $0 >= yesterdayStart && $0 < todayStart.addingTimeInterval(24 * 60 * 60) } ?? false
            guard isRecentSession || modifiedAt >= todayStart else { continue }

            let key = url.standardizedFileURL.path
            if var state = tailStates[key] {
                state.modificationDate = modifiedAt
                let size = (attributes[.size] as? NSNumber)?.uint64Value ?? state.fileSize
                tailStates[key] = state
                if size != state.fileSize { readAppendedData(for: key, state: &state, fileSize: size) }
            } else {
                var state = RolloutTailState(url: url, sessionStartedAt: sessionDate)
                tailStates[key] = state
                let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
                readAppendedData(for: key, state: &state, fileSize: size)
            }
        }
    }

    /// Stats a bounded set of most-recent files, then reads only bytes beyond each saved offset.
    private func pollRecentFiles() {
        let recentKeys = tailStates.keys.sorted {
            (tailStates[$0]?.modificationDate ?? .distantPast) > (tailStates[$1]?.modificationDate ?? .distantPast)
        }.prefix(maximumFilesPerPoll)

        for key in recentKeys {
            guard var state = tailStates[key],
                  let attributes = try? FileManager.default.attributesOfItem(atPath: state.url.path) else { continue }
            let size = (attributes[.size] as? NSNumber)?.uint64Value ?? state.fileSize
            state.modificationDate = attributes[.modificationDate] as? Date ?? state.modificationDate
            if size != state.fileSize {
                readAppendedData(for: key, state: &state, fileSize: size)
            } else {
                tailStates[key] = state
            }
        }
    }

    /// Rebuilds a rollout baseline if truncated, otherwise seeks directly to appended bytes.
    private func readAppendedData(for key: String, state: inout RolloutTailState, fileSize: UInt64) {
        if fileSize < state.byteOffset {
            accumulator.removeSession(key)
            state.byteOffset = 0
            state.fileSize = 0
            state.lineBuffer = JSONLLineBuffer()
        }

        guard fileSize > state.byteOffset else {
            state.fileSize = fileSize
            tailStates[key] = state
            return
        }
        guard let handle = try? FileHandle(forReadingFrom: state.url) else {
            // Leave the stored size behind so a later poll retries this unreadable file.
            tailStates[key] = state
            return
        }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: state.byteOffset)
            while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
                state.byteOffset += UInt64(chunk.count)
                for line in state.lineBuffer.append(chunk) {
                    guard let event = RolloutTokenParser.parse(line: line) else { continue }
                    accumulator.record(
                        event,
                        sessionID: key,
                        sessionStartedAt: state.sessionStartedAt,
                        calendar: calendar
                    )
                }
            }
            state.fileSize = state.byteOffset
            tailStates[key] = state
        } catch {
            // Local history is optional; an unreadable rollout must not affect quota refresh.
            tailStates[key] = state
        }
    }

    /// Resolves the session's local creation date from its YYYY/MM/DD directory components.
    private func sessionStartDate(for url: URL) -> Date? {
        let components = url.deletingLastPathComponent().pathComponents
        guard components.count >= 3,
              let year = Int(components[components.count - 3]),
              let month = Int(components[components.count - 2]),
              let day = Int(components[components.count - 1]) else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    private func isRolloutFile(_ url: URL) -> Bool {
        url.pathExtension == "jsonl" && url.lastPathComponent.hasPrefix("rollout-")
    }
}
