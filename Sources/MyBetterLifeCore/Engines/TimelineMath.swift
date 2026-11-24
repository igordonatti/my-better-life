import Foundation

/// Pure math & formatting helpers for the 24-hour timeline with 15-minute snapping.
public enum TimelineMath {
    public static let snapMinutes: Int = 15
    public static let minutesPerDay: Int = 24 * 60
    public static let minBlockDurationMinutes: Int = 15

    /// Snaps a raw minute-of-day value to the nearest 15-minute increment, clamped to `[0, 1440]`.
    public static func snap(minute: Double, interval: Int = snapMinutes) -> Int {
        guard interval > 0 else { return max(0, min(minutesPerDay, Int(minute.rounded()))) }
        let snapped = Int((minute / Double(interval)).rounded()) * interval
        return max(0, min(minutesPerDay, snapped))
    }

    /// Snaps a signed minute delta (positive OR negative, e.g. dragging up or down) to the nearest 15-minute increment.
    public static func snapDelta(minutes: Double, interval: Int = snapMinutes) -> Int {
        guard interval > 0 else { return Int(minutes.rounded()) }
        return Int((minutes / Double(interval)).rounded()) * interval
    }

    /// Converts a vertical Y position on the timeline grid to snapped minutes of day.
    public static func minuteOfDay(forY y: Double, hourHeight: Double) -> Int {
        guard hourHeight > 0 else { return 0 }
        let rawMinutes = (y / hourHeight) * 60.0
        return snap(minute: rawMinutes)
    }

    /// Converts minutes of day to vertical Y position on the timeline grid.
    public static func yPosition(forMinute minute: Int, hourHeight: Double) -> Double {
        (Double(minute) / 60.0) * hourHeight
    }

    /// Computes minute-of-day `[0, 1440]` of a Date relative to a specific calendar day.
    public static func minuteOfDay(for date: Date, on day: Date, calendar: Calendar = .current) -> Int {
        let dayStart = calendar.startOfDay(for: day)
        let diff = date.timeIntervalSince(dayStart) / 60.0
        return max(0, min(minutesPerDay, Int(diff.rounded())))
    }

    /// Builds a Date on `day` at `minuteOfDay` (0..1440).
    public static func date(on day: Date, minuteOfDay: Int, calendar: Calendar = .current) -> Date {
        let clamped = max(0, min(minutesPerDay, minuteOfDay))
        let dayStart = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .minute, value: clamped, to: dayStart) ?? dayStart
    }

    /// Returns the 7 days of the week containing `date`, starting on Monday.
    public static func weekDays(containing date: Date, calendar: Calendar = .current) -> [Date] {
        var cal = calendar
        cal.firstWeekday = 2 // Monday
        let startOfDay = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: startOfDay)
        // Offset back to Monday (weekday 2)
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) else {
            return [startOfDay]
        }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    /// Formats a minute-of-day (e.g. 540 -> "09:00").
    public static func formatMinute(_ minute: Int) -> String {
        let clamped = max(0, min(minutesPerDay, minute))
        let h = clamped / 60
        let m = clamped % 60
        return String(format: "%02d:%02d", h, m)
    }

    /// Formats a `Date` clock time (e.g. "09:30").
    public static func formatTime(_ date: Date, calendar: Calendar = .current) -> String {
        let h = calendar.component(.hour, from: date)
        let m = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d", h, m)
    }

    /// Formats a time range (e.g. "09:00 – 10:30").
    public static func formatTimeRange(start: Date, end: Date, calendar: Calendar = .current) -> String {
        let sH = calendar.component(.hour, from: start)
        let sM = calendar.component(.minute, from: start)
        let eH = calendar.component(.hour, from: end)
        let eM = calendar.component(.minute, from: end)
        return String(format: "%02d:%02d – %02d:%02d", sH, sM, eH, eM)
    }

    /// Formats a duration in minutes (e.g. "1h 30min" or "45min").
    public static func formatDuration(minutes: Int) -> String {
        let safe = max(0, minutes)
        let h = safe / 60
        let m = safe % 60
        if h > 0 && m > 0 {
            return "\(h)h \(m)min"
        } else if h > 0 {
            return "\(h)h"
        } else {
            return "\(m)min"
        }
    }

    /// Formats hour label for the timeline gutter (e.g. "07:00", "14:00").
    public static func formatHourLabel(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }
}
