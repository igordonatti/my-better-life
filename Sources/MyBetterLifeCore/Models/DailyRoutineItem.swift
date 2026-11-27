import Foundation

/// A recurring daily checklist item displayed in the Sidebar's "Rotina" card.
/// Unlike `InboxItem`, it resets automatically on each new day and tracks per-day completion history
/// via `DailyRoutineCompletion`. Can also be dragged onto the Day Timeline to create a linked `TimeBlock`.
public struct DailyRoutineItem: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var title: String
    public var estimatedMinutes: Int
    public var weekdaysMask: WeekdayMask
    public var categoryID: UUID?
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        estimatedMinutes: Int = 30,
        weekdaysMask: WeekdayMask = .all,
        categoryID: UUID? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.estimatedMinutes = max(15, estimatedMinutes)
        self.weekdaysMask = weekdaysMask.isEmpty ? .all : weekdaysMask
        self.categoryID = categoryID
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    /// Returns true if this routine item should appear on the given calendar day.
    public func applies(to date: Date, calendar: Calendar = .current) -> Bool {
        let mask = weekdaysMask.isEmpty ? .all : weekdaysMask
        let weekday = calendar.component(.weekday, from: date)
        return mask.contains(calendarWeekday: weekday)
    }

    /// Short human-readable summary of the active weekday schedule (e.g., "Seg–Sex", "Fins de semana", or "Seg, Qua, Sex").
    /// Returns `nil` when active every day (7/7).
    public var scheduleSummary: String? {
        let mask = weekdaysMask.isEmpty ? .all : weekdaysMask
        if mask == .all { return nil }
        if mask == .weekdays { return "Seg–Sex" }
        if mask == .weekend { return "Fins de sem." }
        let labels = WeekdayMask.orderedForUI
            .filter { mask.contains($0.mask) }
            .map(\.shortLabel)
        return labels.joined(separator: ", ")
    }
}

/// Per-day completion record for a `DailyRoutineItem`.
/// Keyed by local calendar day (`yyyy-MM-dd`) so completion history is timezone-resilient.
public struct DailyRoutineCompletion: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var routineItemID: UUID
    public var dayKey: String
    public var isCompleted: Bool
    public var completedAt: Date?
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        routineItemID: UUID,
        dayKey: String,
        isCompleted: Bool,
        completedAt: Date? = nil,
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.routineItemID = routineItemID
        self.dayKey = dayKey
        self.isCompleted = isCompleted
        self.completedAt = isCompleted ? (completedAt ?? updatedAt) : nil
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    /// Formats a `Date` into a stable local calendar day key (`yyyy-MM-dd`).
    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let year = comps.year ?? 1970
        let month = comps.month ?? 1
        let day = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
