import Foundation

/// Selectable reporting timeframe for the Insights workspace.
public enum InsightsPeriod: String, CaseIterable, Identifiable, Sendable {
    case week
    case month
    case quarter

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .week: return "Semana"
        case .month: return "Mês"
        case .quarter: return "90 dias"
        }
    }

    public var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }
}

public struct CategoryTimeStat: Identifiable, Equatable, Sendable {
    public let id: String
    public let categoryID: UUID?
    public let name: String
    public let colorHex: String
    public let totalMinutes: Int
    public let completedMinutes: Int
    public let blockCount: Int
    public let share: Double
}

public struct GlobalBlockTimeStat: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let note: StandaloneNote
    public let categoryColorHex: String
    public let totalMinutes: Int
    public let completedMinutes: Int
    public let sessionCount: Int
    public let completedSessionCount: Int
}

public struct DailyCategoryMinutes: Identifiable, Equatable, Sendable {
    public let id: String
    public let day: Date
    public let categoryName: String
    public let colorHex: String
    public let minutes: Int
}

public struct RoutineStreakStat: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let series: RecurrenceSeries
    public let categoryColorHex: String
    public let currentStreak: Int
    public let bestStreak: Int
    public let completedInPeriod: Int
    public let scheduledInPeriod: Int
}

public struct InsightsReport: Sendable {
    public let period: InsightsPeriod
    public let startDate: Date
    public let endDate: Date
    public let totalPlannedMinutes: Int
    public let completedMinutes: Int
    public let totalBlocksCount: Int
    public let completedBlocksCount: Int
    public let globalBlocksMinutes: Int
    public let bestCurrentStreak: Int
    public let categoryStats: [CategoryTimeStat]
    public let globalBlockStats: [GlobalBlockTimeStat]
    public let dailyBreakdown: [DailyCategoryMinutes]
    public let routineStreaks: [RoutineStreakStat]

    public var completionRate: Double {
        guard totalBlocksCount > 0 else { return 0 }
        return Double(completedBlocksCount) / Double(totalBlocksCount)
    }
}

/// Pure analytics engine computing time investment per Global Block, per Category,
/// daily stacked breakdowns, completion rates, and recurring routine streaks.
public enum InsightsEngine {
    public static func dateRange(
        for period: InsightsPeriod,
        offset: Int = 0,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let today = calendar.startOfDay(for: referenceDate)
        switch period {
        case .week:
            let baseWeek = TimelineMath.weekDays(containing: today, calendar: calendar)
            let baseStart = baseWeek.first ?? today
            let shiftedStart = calendar.date(byAdding: .day, value: offset * 7, to: baseStart) ?? baseStart
            let shiftedEnd = calendar.date(byAdding: .day, value: 6, to: shiftedStart) ?? shiftedStart
            return (shiftedStart, shiftedEnd)
        case .month:
            let anchor = calendar.date(byAdding: .month, value: offset, to: today) ?? today
            if let interval = calendar.dateInterval(of: .month, for: anchor),
               let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) {
                return (calendar.startOfDay(for: interval.start), calendar.startOfDay(for: lastDay))
            }
            return (today, today)
        case .quarter:
            let shiftedEnd = calendar.date(byAdding: .day, value: offset * 90, to: today) ?? today
            let shiftedStart = calendar.date(byAdding: .day, value: -89, to: shiftedEnd) ?? shiftedEnd
            return (shiftedStart, shiftedEnd)
        }
    }

    public static func generate(
        period: InsightsPeriod,
        offset: Int = 0,
        blocks: [TimeBlock],
        seriesList: [RecurrenceSeries],
        notes: [StandaloneNote],
        categories: [BlockCategory],
        attachments: [BlockAttachment] = [],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> InsightsReport {
        let (rangeStart, rangeEnd) = dateRange(for: period, offset: offset, referenceDate: referenceDate, calendar: calendar)
        let categoryByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        var totalPlannedMinutes = 0
        var completedMinutes = 0
        var totalBlocksCount = 0
        var completedBlocksCount = 0
        var globalBlocksMinutes = 0

        struct CatAccum {
            var categoryID: UUID?
            var name: String
            var colorHex: String
            var totalMinutes: Int = 0
            var completedMinutes: Int = 0
            var count: Int = 0
        }
        var catMap: [String: CatAccum] = [:]

        struct GlobalAccum {
            var note: StandaloneNote
            var colorHex: String
            var totalMinutes: Int = 0
            var completedMinutes: Int = 0
            var sessions: Int = 0
            var completedSessions: Int = 0
        }
        var globalMap: [UUID: GlobalAccum] = [:]

        var dailyBreakdown: [DailyCategoryMinutes] = []

        var cursor = rangeStart
        while cursor <= rangeEnd {
            let dayOccurrences = RecurrenceEngine.occurrences(
                on: cursor,
                blocks: blocks,
                seriesList: seriesList,
                notes: notes,
                categories: categories,
                attachments: attachments,
                calendar: calendar
            )

            var dayByCat: [String: (name: String, colorHex: String, minutes: Int)] = [:]

            for occ in dayOccurrences {
                totalBlocksCount += 1
                if occ.isCompleted {
                    completedBlocksCount += 1
                }

                // Timed minutes only (all-day blocks count toward completion count but not timed hours)
                let minutes: Int = occ.isAllDay
                    ? 0
                    : max(15, Int(round(occ.endDate.timeIntervalSince(occ.startDate) / 60.0)))

                totalPlannedMinutes += minutes
                if occ.isCompleted {
                    completedMinutes += minutes
                }

                let catKey = occ.category?.id.uuidString ?? "uncategorized"
                let catName = occ.category?.name ?? L10n.noCategory
                let catHex = occ.category?.colorHex ?? "#64748B"

                var catEntry = catMap[catKey] ?? CatAccum(categoryID: occ.category?.id, name: catName, colorHex: catHex)
                catEntry.totalMinutes += minutes
                if occ.isCompleted { catEntry.completedMinutes += minutes }
                catEntry.count += 1
                catMap[catKey] = catEntry

                if minutes > 0 {
                    var dayEntry = dayByCat[catKey] ?? (name: catName, colorHex: catHex, minutes: 0)
                    dayEntry.minutes += minutes
                    dayByCat[catKey] = dayEntry
                }

                if let globalNote = occ.globalNote {
                    globalBlocksMinutes += minutes
                    let gColor = globalNote.categoryID.flatMap { categoryByID[$0]?.colorHex } ?? catHex
                    var gEntry = globalMap[globalNote.id] ?? GlobalAccum(note: globalNote, colorHex: gColor)
                    gEntry.totalMinutes += minutes
                    if occ.isCompleted {
                        gEntry.completedMinutes += minutes
                        gEntry.completedSessions += 1
                    }
                    gEntry.sessions += 1
                    globalMap[globalNote.id] = gEntry
                }
            }

            if dayByCat.isEmpty {
                dailyBreakdown.append(DailyCategoryMinutes(
                    id: "\(Int(cursor.timeIntervalSince1970))-empty",
                    day: cursor,
                    categoryName: L10n.noCategory,
                    colorHex: "#CBD5E1",
                    minutes: 0
                ))
            } else {
                for (key, value) in dayByCat.sorted(by: { $0.value.minutes > $1.value.minutes }) {
                    dailyBreakdown.append(DailyCategoryMinutes(
                        id: "\(Int(cursor.timeIntervalSince1970))-\(key)",
                        day: cursor,
                        categoryName: value.name,
                        colorHex: value.colorHex,
                        minutes: value.minutes
                    ))
                }
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = nextDay
        }

        let categoryStats = catMap.values
            .filter { $0.totalMinutes > 0 }
            .sorted { $0.totalMinutes > $1.totalMinutes }
            .map { entry in
                CategoryTimeStat(
                    id: entry.categoryID?.uuidString ?? "uncategorized",
                    categoryID: entry.categoryID,
                    name: entry.name,
                    colorHex: entry.colorHex,
                    totalMinutes: entry.totalMinutes,
                    completedMinutes: entry.completedMinutes,
                    blockCount: entry.count,
                    share: totalPlannedMinutes > 0 ? Double(entry.totalMinutes) / Double(totalPlannedMinutes) : 0
                )
            }

        let globalBlockStats = globalMap.values
            .sorted { lhs, rhs in
                if lhs.totalMinutes != rhs.totalMinutes {
                    return lhs.totalMinutes > rhs.totalMinutes
                }
                return lhs.sessions > rhs.sessions
            }
            .map { entry in
                GlobalBlockTimeStat(
                    id: entry.note.id,
                    note: entry.note,
                    categoryColorHex: entry.colorHex,
                    totalMinutes: entry.totalMinutes,
                    completedMinutes: entry.completedMinutes,
                    sessionCount: entry.sessions,
                    completedSessionCount: entry.completedSessions
                )
            }

        let routineStreaks = computeRoutineStreaks(
            seriesList: seriesList,
            blocks: blocks,
            categories: categories,
            periodStart: rangeStart,
            periodEnd: rangeEnd,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let bestCurrentStreak = routineStreaks.map(\.currentStreak).max() ?? 0

        return InsightsReport(
            period: period,
            startDate: rangeStart,
            endDate: rangeEnd,
            totalPlannedMinutes: totalPlannedMinutes,
            completedMinutes: completedMinutes,
            totalBlocksCount: totalBlocksCount,
            completedBlocksCount: completedBlocksCount,
            globalBlocksMinutes: globalBlocksMinutes,
            bestCurrentStreak: bestCurrentStreak,
            categoryStats: categoryStats,
            globalBlockStats: globalBlockStats,
            dailyBreakdown: dailyBreakdown,
            routineStreaks: routineStreaks
        )
    }

    private static func computeRoutineStreaks(
        seriesList: [RecurrenceSeries],
        blocks: [TimeBlock],
        categories: [BlockCategory],
        periodStart: Date,
        periodEnd: Date,
        referenceDate: Date,
        calendar: Calendar
    ) -> [RoutineStreakStat] {
        let today = calendar.startOfDay(for: referenceDate)
        let categoryByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        return seriesList.map { series in
            let overridesByDay: [Date: TimeBlock] = Dictionary(
                blocks
                    .filter { $0.seriesID == series.id && $0.occurrenceOriginalDate != nil }
                    .compactMap { b -> (Date, TimeBlock)? in
                        guard let orig = b.occurrenceOriginalDate else { return nil }
                        return (calendar.startOfDay(for: orig), b)
                    },
                uniquingKeysWith: { _, latest in latest }
            )

            // Look back up to 180 days from today to compute current & best streak
            let lookbackStart = max(
                calendar.startOfDay(for: series.seriesStartDate),
                calendar.date(byAdding: .day, value: -180, to: today) ?? today
            )

            var bestStreak = 0
            var running = 0
            var completedInPeriod = 0
            var scheduledInPeriod = 0

            var day = lookbackStart
            var occurrenceResults: [(day: Date, completed: Bool)] = []
            while day <= today {
                if RecurrenceEngine.seriesOccurs(series, on: day, calendar: calendar) {
                    let override = overridesByDay[day]
                    if override?.isDeletedOverride != true {
                        let done = override?.isCompleted ?? false
                        occurrenceResults.append((day, done))
                        if done {
                            running += 1
                            bestStreak = max(bestStreak, running)
                        } else {
                            running = 0
                        }
                        if day >= periodStart && day <= periodEnd {
                            scheduledInPeriod += 1
                            if done { completedInPeriod += 1 }
                        }
                    }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }

            // Current streak: count backwards from most recent occurrence.
            // If today itself is scheduled and not yet completed, don't break yesterday's active streak!
            var currentStreak = 0
            for (idx, entry) in occurrenceResults.reversed().enumerated() {
                if idx == 0 && calendar.isDate(entry.day, inSameDayAs: today) && !entry.completed {
                    continue
                }
                if entry.completed {
                    currentStreak += 1
                } else {
                    break
                }
            }

            let colorHex = series.categoryID.flatMap { categoryByID[$0]?.colorHex } ?? "#64748B"
            return RoutineStreakStat(
                id: series.id,
                series: series,
                categoryColorHex: colorHex,
                currentStreak: currentStreak,
                bestStreak: bestStreak,
                completedInPeriod: completedInPeriod,
                scheduledInPeriod: scheduledInPeriod
            )
        }
        .sorted { lhs, rhs in
            if lhs.currentStreak != rhs.currentStreak {
                return lhs.currentStreak > rhs.currentStreak
            }
            return lhs.bestStreak > rhs.bestStreak
        }
    }
}
