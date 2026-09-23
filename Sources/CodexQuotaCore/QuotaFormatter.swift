import Foundation
import SwiftUI

/// Shared Chinese display formatting for durations, percentages, and status.
public enum QuotaFormatter {
    public static func windowTitle(minutes: Int?) -> String {
        guard let minutes else { return "额度窗口" }
        if minutes == 10080 { return "周额度" }
        return "\(duration(minutes: minutes))额度"
    }

    /// Short label used in the compact tooltip without repeating “额度”.
    public static func compactWindowTitle(minutes: Int?) -> String {
        guard let minutes else { return "额度" }
        if minutes == 10080 { return "周额度" }
        return duration(minutes: minutes)
    }

    public static func duration(minutes: Int) -> String {
        if minutes % 1440 == 0 {
            let days = minutes / 1440
            return days == 1 ? "24 小时" : "\(days) 天"
        }
        if minutes % 60 == 0 { return "\(minutes / 60) 小时" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 { return "\(hours) 小时 \(remainingMinutes) 分" }
        return "\(remainingMinutes) 分钟"
    }

    public static func countdown(to date: Date?, now: Date = .now) -> String {
        guard let date else { return "重置时间未知" }
        let seconds = Int(date.timeIntervalSince(now))
        guard seconds > 0 else { return "已重置 / 时间已到" }

        let minutes = max(1, Int(ceil(Double(seconds) / 60)))
        if minutes < 60 { return "\(minutes) 分钟后重置" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours < 24 {
            return remainingMinutes == 0 ? "\(hours) 小时后重置" : "\(hours) 小时 \(remainingMinutes) 分后重置"
        }
        let days = hours / 24
        let remainingHours = hours % 24
        return remainingHours == 0 ? "\(days) 天后重置" : "\(days) 天 \(remainingHours) 小时后重置"
    }

    public static func absoluteDate(_ date: Date?) -> String {
        guard let date else { return "重置时间未知" }
        return date.formatted(.dateTime.year().month().day().hour().minute())
    }

    public static func relativeUpdate(_ date: Date?, now: Date = .now) -> String {
        guard let date else { return "尚未更新" }
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "刚刚更新" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) 分钟前更新" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) 小时前更新" }
        return "\(hours / 24) 天前更新"
    }

    public static func color(for remaining: Int) -> Color {
        switch remaining {
        case ...10: return .red
        case 11...25: return .orange
        default: return .blue
        }
    }
}
