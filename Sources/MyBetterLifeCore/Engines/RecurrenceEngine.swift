import Foundation

/// Scope when editing or deleting a recurring block's schedule or series.
public enum RecurrenceEditScope: Sendable {
    case onlyThisDay
    case thisAndFuture
    case entireSeries
}

/// Represents a concrete renderable item on a specific day:
/// either a standalone `TimeBlock`, a materialized per-day override of a `RecurrenceSeries`,
/// or a virtual occurrence expanded from a `RecurrenceSeries` template.
public struct DayOccurrence: Identifiable, Sendable, Equatable {
    public let id: String
    public let dayStart: Date
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let title: String
    public let isCompleted: Bool
    public let reminderMinutesBefore: Int?
    public let noteMarkdown: String
    public let category: BlockCategory?
    public let block: TimeBlock?
    public let series: RecurrenceSeries?
    public let globalNote: StandaloneNote?
    public let attachmentCount: Int

    public var isRecurring: Bool { series != nil }
    public var isGlobalLinked: Bool { globalNote != nil }
    public var isVirtualOccurrence: Bool { block == nil && series != nil }

    public var summary: RichNoteSummary {
        RichNoteDocument.summarize(markdown: noteMarkdown, attachmentCount: attachmentCount)
    }

    public init(
        id: String,
        dayStart: Date,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        title: String,
        isCompleted: Bool,
        reminderMinutesBefore: Int?,
        noteMarkdown: String,
        category: BlockCategory?,
        block: TimeBlock?,
        series: RecurrenceSeries?,
        globalNote: StandaloneNote? = nil,
        attachmentCount: Int
    ) {
        self.id = id
        self.dayStart = dayStart
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.title = title
        self.isCompleted = isCompleted
        self.reminderMinutesBefore = reminderMinutesBefore
        self.noteMarkdown = noteMarkdown
        self.category = category
        self.block = block
        self.series = series
        self.globalNote = globalNote
        self.attachmentCount = attachmentCount
    }
}

/// Expands recurring series and standalone blocks into concrete day occurrences,
/// and manages per-day override materialization.
public enum RecurrenceEngine {
    /// Checks whether a `RecurrenceSeries` occurs on a given calendar day.
    public static func seriesOccurs(
        _ series: RecurrenceSeries,
        on day: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        let start = calendar.startOfDay(for: series.seriesStartDate)
        if dayStart < start { return false }
        if let end = series.seriesEndDate, dayStart > calendar.startOfDay(for: end) {
            return false
        }

        switch series.ruleType {
        case .daily:
            return true
        case .weekdays:
            let weekday = calendar.component(.weekday, from: dayStart)
            return WeekdayMask.weekdays.contains(calendarWeekday: weekday)
        case .weekly:
            let weekday = calendar.component(.weekday, from: dayStart)
            let mask = series.weekdaysMask
            if mask.isEmpty {
                let startWeekday = calendar.component(.weekday, from: start)
                return weekday == startWeekday
            }
            return mask.contains(calendarWeekday: weekday)
        case .monthly:
            let targetDay = calendar.component(.day, from: start)
            let currentDay = calendar.component(.day, from: dayStart)
            if let range = calendar.range(of: .day, in: .month, for: dayStart) {
                let clampedTarget = min(targetDay, range.upperBound - 1)
                return currentDay == clampedTarget
            }
            return currentDay == targetDay
        }
    }

    /// Computes all occurrences for a single calendar day, respecting category filters,
    /// per-day overrides, and live Global Block content links.
    public static func occurrences(
        on day: Date,
        blocks: [TimeBlock],
        seriesList: [RecurrenceSeries],
        notes: [StandaloneNote] = [],
        categories: [BlockCategory] = [],
        attachments: [BlockAttachment] = [],
        categoryFilterID: UUID? = nil,
        calendar: Calendar = .current
    ) -> [DayOccurrence] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }

        let categoryByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let noteByID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        let blockAttachmentCounts = Dictionary(grouping: attachments.compactMap(\.blockID), by: { $0 }).mapValues(\.count)
        let seriesAttachmentCounts = Dictionary(grouping: attachments.compactMap(\.seriesID), by: { $0 }).mapValues(\.count)
        let noteAttachmentCounts = Dictionary(grouping: attachments.compactMap(\.noteID), by: { $0 }).mapValues(\.count)

        var results: [DayOccurrence] = []

        // Index overrides by series ID for this day
        var overrideBySeriesID: [UUID: TimeBlock] = [:]
        for block in blocks {
            if let sID = block.seriesID, let orig = block.occurrenceOriginalDate {
                if calendar.isDate(orig, inSameDayAs: dayStart) {
                    overrideBySeriesID[sID] = block
                }
            }
        }

        // 1. Standalone blocks on this day
        for block in blocks where block.seriesID == nil && !block.isDeletedOverride {
            let overlapsDay = block.isAllDay
                ? calendar.isDate(block.startDate, inSameDayAs: dayStart)
                : (block.startDate < dayEnd && block.endDate > dayStart)

            guard overlapsDay else { continue }
            let linkedGlobal = block.globalNoteID.flatMap { noteByID[$0] }
            let resolvedCategoryID = linkedGlobal?.categoryID ?? block.categoryID
            if let filterID = categoryFilterID, resolvedCategoryID != filterID { continue }

            let clampedStart = block.isAllDay ? dayStart : max(block.startDate, dayStart)
            let clampedEnd = block.isAllDay ? dayEnd : min(block.endDate, dayEnd)

            results.append(DayOccurrence(
                id: "block-\(block.id.uuidString)",
                dayStart: dayStart,
                startDate: clampedStart,
                endDate: max(clampedEnd, clampedStart.addingTimeInterval(15 * 60)),
                isAllDay: block.isAllDay,
                title: linkedGlobal?.title ?? block.title,
                isCompleted: block.isCompleted,
                reminderMinutesBefore: block.reminderMinutesBefore,
                noteMarkdown: linkedGlobal?.noteMarkdown ?? block.noteMarkdown,
                category: resolvedCategoryID.flatMap { categoryByID[$0] },
                block: block,
                series: nil,
                globalNote: linkedGlobal,
                attachmentCount: linkedGlobal.map { noteAttachmentCounts[$0.id] ?? 0 } ?? (blockAttachmentCounts[block.id] ?? 0)
            ))
        }

        // 2. Recurring series occurrences (using materialized override if present)
        for series in seriesList where series.deletedAt == nil {
            guard seriesOccurs(series, on: dayStart, calendar: calendar) else { continue }

            if let override = overrideBySeriesID[series.id] {
                if override.isDeletedOverride {
                    continue
                }
                let linkedGlobal = (override.globalNoteID ?? series.globalNoteID).flatMap { noteByID[$0] }
                let resolvedCategoryID = linkedGlobal?.categoryID ?? override.categoryID
                if let filterID = categoryFilterID, resolvedCategoryID != filterID {
                    continue
                }
                results.append(DayOccurrence(
                    id: "override-\(override.id.uuidString)",
                    dayStart: dayStart,
                    startDate: override.startDate,
                    endDate: override.endDate,
                    isAllDay: override.isAllDay,
                    title: linkedGlobal?.title ?? override.title,
                    isCompleted: override.isCompleted,
                    reminderMinutesBefore: override.reminderMinutesBefore,
                    noteMarkdown: linkedGlobal?.noteMarkdown ?? override.noteMarkdown,
                    category: resolvedCategoryID.flatMap { categoryByID[$0] },
                    block: override,
                    series: series,
                    globalNote: linkedGlobal,
                    attachmentCount: linkedGlobal.map { noteAttachmentCounts[$0.id] ?? 0 } ?? (blockAttachmentCounts[override.id] ?? 0)
                ))
            } else {
                let linkedGlobal = series.globalNoteID.flatMap { noteByID[$0] }
                let resolvedCategoryID = linkedGlobal?.categoryID ?? series.categoryID
                if let filterID = categoryFilterID, resolvedCategoryID != filterID {
                    continue
                }
                let start = series.isAllDay
                    ? dayStart
                    : TimelineMath.date(on: dayStart, minuteOfDay: series.startMinuteOfDay, calendar: calendar)
                let end = series.isAllDay
                    ? dayEnd
                    : start.addingTimeInterval(TimeInterval(max(15, series.durationMinutes) * 60))

                let dayStamp = Int(dayStart.timeIntervalSince1970)
                results.append(DayOccurrence(
                    id: "virtual-\(series.id.uuidString)-\(dayStamp)",
                    dayStart: dayStart,
                    startDate: start,
                    endDate: end,
                    isAllDay: series.isAllDay,
                    title: linkedGlobal?.title ?? series.title,
                    isCompleted: false,
                    reminderMinutesBefore: series.reminderMinutesBefore,
                    noteMarkdown: linkedGlobal?.noteMarkdown ?? series.templateMarkdown,
                    category: resolvedCategoryID.flatMap { categoryByID[$0] },
                    block: nil,
                    series: series,
                    globalNote: linkedGlobal,
                    attachmentCount: linkedGlobal.map { noteAttachmentCounts[$0.id] ?? 0 } ?? (seriesAttachmentCounts[series.id] ?? 0)
                ))
            }
        }

        return results.sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
            if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    /// Materializes a virtual recurring occurrence into an independent per-day `TimeBlock` override,
    /// inheriting the series' template markdown & attachments so edits stay scoped to that day.
    @MainActor
    public static func materializeOverride(
        for series: RecurrenceSeries,
        on day: Date,
        in store: PlannerStore,
        calendar: Calendar = .current
    ) -> TimeBlock {
        let dayStart = calendar.startOfDay(for: day)

        if var existing = store.blocks.first(where: {
            $0.seriesID == series.id &&
            $0.occurrenceOriginalDate.map({ calendar.isDate($0, inSameDayAs: dayStart) }) == true
        }) {
            if existing.isDeletedOverride {
                existing.isDeletedOverride = false
                existing.updatedAt = Date()
                store.upsertBlock(existing)
            }
            return existing
        }

        let start = series.isAllDay
            ? dayStart
            : TimelineMath.date(on: dayStart, minuteOfDay: series.startMinuteOfDay, calendar: calendar)
        let end = series.isAllDay
            ? (calendar.date(byAdding: .day, value: 1, to: dayStart) ?? start.addingTimeInterval(3600))
            : start.addingTimeInterval(TimeInterval(max(15, series.durationMinutes) * 60))

        var clonedMarkdown = series.templateMarkdown
        var override = TimeBlock(
            title: series.title,
            startDate: start,
            endDate: end,
            isAllDay: series.isAllDay,
            isCompleted: false,
            reminderMinutesBefore: series.reminderMinutesBefore,
            noteMarkdown: clonedMarkdown,
            categoryID: series.categoryID,
            seriesID: series.id,
            globalNoteID: series.globalNoteID,
            occurrenceOriginalDate: dayStart,
            isDeletedOverride: false
        )

        let templateAttachments = store.attachments(forSeriesID: series.id)
        for att in templateAttachments {
            let newID = UUID()
            let copy = BlockAttachment(
                id: newID,
                fileName: att.fileName,
                mimeType: att.mimeType,
                imageData: att.imageData,
                blockID: override.id
            )
            store.upsertAttachment(copy)
            clonedMarkdown = clonedMarkdown.replacingOccurrences(
                of: att.id.uuidString,
                with: newID.uuidString,
                options: .caseInsensitive
            )
        }
        override.updateNoteMarkdown(clonedMarkdown, attachmentCount: templateAttachments.count)
        store.upsertBlock(override)
        return override
    }

    /// Converts a standalone `TimeBlock` into a `RecurrenceSeries` starting on its day,
    /// keeping the original block as the materialized override for its starting day.
    @MainActor
    public static func convertToRecurringSeries(
        block: TimeBlock,
        ruleType: RecurrenceRuleType,
        weekdaysMask: WeekdayMask,
        in store: PlannerStore,
        calendar: Calendar = .current
    ) -> RecurrenceSeries {
        let dayStart = calendar.startOfDay(for: block.startDate)
        let startMin = TimelineMath.minuteOfDay(for: block.startDate, on: dayStart, calendar: calendar)
        let endMin = TimelineMath.minuteOfDay(for: block.endDate, on: dayStart, calendar: calendar)
        let duration = max(15, endMin - startMin)

        var series = RecurrenceSeries(
            title: block.title,
            ruleType: ruleType,
            weekdaysMask: weekdaysMask,
            startMinuteOfDay: startMin,
            durationMinutes: duration,
            isAllDay: block.isAllDay,
            reminderMinutesBefore: block.reminderMinutesBefore,
            templateMarkdown: block.noteMarkdown,
            seriesStartDate: dayStart,
            categoryID: block.categoryID,
            globalNoteID: block.globalNoteID
        )

        let blockAttachments = store.attachments(forBlockID: block.id)
        if !blockAttachments.isEmpty {
            var templateMD = block.noteMarkdown
            for att in blockAttachments {
                let newID = UUID()
                let templateAtt = BlockAttachment(
                    id: newID,
                    fileName: att.fileName,
                    mimeType: att.mimeType,
                    imageData: att.imageData,
                    seriesID: series.id
                )
                store.upsertAttachment(templateAtt)
                templateMD = templateMD.replacingOccurrences(
                    of: att.id.uuidString,
                    with: newID.uuidString,
                    options: .caseInsensitive
                )
            }
            series.updateTemplateMarkdown(templateMD, attachmentCount: blockAttachments.count)
        }
        store.upsertSeries(series)

        var updatedBlock = block
        updatedBlock.seriesID = series.id
        updatedBlock.occurrenceOriginalDate = dayStart
        updatedBlock.updatedAt = Date()
        store.upsertBlock(updatedBlock)

        return series
    }

    /// Returns dates in a given month that have at least one block or recurring occurrence.
    public static func activeDaysInMonth(
        containing monthDate: Date,
        blocks: [TimeBlock],
        seriesList: [RecurrenceSeries],
        calendar: Calendar = .current
    ) -> Set<Date> {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else {
            return []
        }
        var activeDays = Set<Date>()
        var current = calendar.startOfDay(for: monthInterval.start)
        while current < monthInterval.end {
            let items = occurrences(on: current, blocks: blocks, seriesList: seriesList, calendar: calendar)
            if !items.isEmpty {
                activeDays.insert(current)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return activeDays
    }
}
