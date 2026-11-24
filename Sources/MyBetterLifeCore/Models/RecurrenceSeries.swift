import Foundation

/// Recurrence rule type for recurring time blocks / routines.
public enum RecurrenceRuleType: String, CaseIterable, Codable, Sendable, Identifiable {
    case daily
    case weekdays
    case weekly
    case monthly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .daily: return L10n.recurrenceDaily
        case .weekdays: return L10n.recurrenceWeekdays
        case .weekly: return L10n.recurrenceWeekly
        case .monthly: return L10n.recurrenceMonthly
        }
    }
}

/// Weekday bitmask helper (Calendar.component(.weekday): 1 = Sunday ... 7 = Saturday).
public struct WeekdayMask: OptionSet, Codable, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let sunday    = WeekdayMask(rawValue: 1 << 0) // Calendar weekday 1
    public static let monday    = WeekdayMask(rawValue: 1 << 1) // Calendar weekday 2
    public static let tuesday   = WeekdayMask(rawValue: 1 << 2) // Calendar weekday 3
    public static let wednesday = WeekdayMask(rawValue: 1 << 3) // Calendar weekday 4
    public static let thursday  = WeekdayMask(rawValue: 1 << 4) // Calendar weekday 5
    public static let friday    = WeekdayMask(rawValue: 1 << 5) // Calendar weekday 6
    public static let saturday  = WeekdayMask(rawValue: 1 << 6) // Calendar weekday 7

    public static let weekdays: WeekdayMask = [.monday, .tuesday, .wednesday, .thursday, .friday]
    public static let all: WeekdayMask = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

    public static func from(calendarWeekday: Int) -> WeekdayMask {
        guard (1...7).contains(calendarWeekday) else { return [] }
        return WeekdayMask(rawValue: 1 << (calendarWeekday - 1))
    }

    public func contains(calendarWeekday: Int) -> Bool {
        contains(Self.from(calendarWeekday: calendarWeekday))
    }

    /// Ordered Mon..Sun for Brazilian/Portuguese UI presentation.
    public static let orderedForUI: [(mask: WeekdayMask, shortLabel: String, calendarWeekday: Int)] = [
        (.monday, "Seg", 2),
        (.tuesday, "Ter", 3),
        (.wednesday, "Qua", 4),
        (.thursday, "Qui", 5),
        (.friday, "Sex", 6),
        (.saturday, "Sáb", 7),
        (.sunday, "Dom", 1)
    ]
}

/// Defines a recurring routine/series with an inherited rich note template.
/// Per-day edits materialize an independent `TimeBlock` override linked to `seriesID`.
public struct RecurrenceSeries: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var title: String
    public var ruleType: RecurrenceRuleType
    public var weekdaysMask: WeekdayMask
    public var startMinuteOfDay: Int
    public var durationMinutes: Int
    public var isAllDay: Bool
    public var reminderMinutesBefore: Int?
    public var templateMarkdown: String
    public var templatePlainText: String
    public var seriesStartDate: Date
    public var seriesEndDate: Date?
    public var categoryID: UUID?
    public var globalNoteID: UUID?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        ruleType: RecurrenceRuleType = .daily,
        weekdaysMask: WeekdayMask = .weekdays,
        startMinuteOfDay: Int = 540,
        durationMinutes: Int = 60,
        isAllDay: Bool = false,
        reminderMinutesBefore: Int? = nil,
        templateMarkdown: String = "",
        seriesStartDate: Date = Date(),
        seriesEndDate: Date? = nil,
        categoryID: UUID? = nil,
        globalNoteID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.ruleType = ruleType
        self.weekdaysMask = weekdaysMask
        self.startMinuteOfDay = startMinuteOfDay
        self.durationMinutes = max(15, durationMinutes)
        self.isAllDay = isAllDay
        self.reminderMinutesBefore = reminderMinutesBefore
        self.templateMarkdown = templateMarkdown
        self.templatePlainText = RichNoteDocument.summarize(markdown: templateMarkdown).plainTextIndex
        self.seriesStartDate = Calendar.current.startOfDay(for: seriesStartDate)
        self.seriesEndDate = seriesEndDate.map { Calendar.current.startOfDay(for: $0) }
        self.categoryID = categoryID
        self.globalNoteID = globalNoteID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    public mutating func updateTemplateMarkdown(_ markdown: String, attachmentCount: Int = 0) {
        self.templateMarkdown = markdown
        self.templatePlainText = RichNoteDocument.summarize(
            markdown: markdown,
            attachmentCount: attachmentCount
        ).plainTextIndex
        self.updatedAt = Date()
    }
}
