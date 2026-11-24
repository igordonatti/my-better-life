import Foundation
import Testing
@testable import MyBetterLifeCore

@Suite("InsightsEngine & ReminderScheduler")
struct InsightsEngineTests {
    private var fixedCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 9) -> Date {
        fixedCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test("Computes Global Block hours, category distribution, completion rate, and routine streaks accurately")
    func computesWeeklyInsightsAndStreaks() {
        let workCat = BlockCategory(name: "Trabalho", colorHex: "#3B82F6")
        let healthCat = BlockCategory(name: "Saúde", colorHex: "#10B981")
        let globalProject = StandaloneNote(title: "Projeto Atlas", isGlobal: true, categoryID: workCat.id)

        // Reference week: Mon 2026-11-23 .. Sun 2026-11-29 (referenceDate = Thu 2026-11-26)
        let mon = makeDate(year: 2026, month: 11, day: 23, hour: 9)
        let tue = makeDate(year: 2026, month: 11, day: 24, hour: 9)
        let wed = makeDate(year: 2026, month: 11, day: 25, hour: 9)
        let thu = makeDate(year: 2026, month: 11, day: 26, hour: 9)

        // Two 2-hour sessions linked to Global Block (one completed, one pending)
        let session1 = TimeBlock(
            title: "Projeto Atlas",
            startDate: mon,
            endDate: mon.addingTimeInterval(120 * 60),
            isCompleted: true,
            categoryID: workCat.id,
            globalNoteID: globalProject.id
        )
        let session2 = TimeBlock(
            title: "Projeto Atlas",
            startDate: tue,
            endDate: tue.addingTimeInterval(120 * 60),
            isCompleted: false,
            categoryID: workCat.id,
            globalNoteID: globalProject.id
        )

        // Daily recurring routine starting Monday (1h each day)
        let workoutSeries = RecurrenceSeries(
            title: "Treino",
            ruleType: .daily,
            weekdaysMask: .all,
            startMinuteOfDay: 7 * 60,
            durationMinutes: 60,
            seriesStartDate: fixedCalendar.startOfDay(for: mon),
            categoryID: healthCat.id
        )

        // Mark Mon, Tue, Wed overrides completed; Thu not yet completed (should keep 3-day active streak!)
        let ovMon = TimeBlock(
            title: "Treino",
            startDate: makeDate(year: 2026, month: 11, day: 23, hour: 7),
            endDate: makeDate(year: 2026, month: 11, day: 23, hour: 8),
            isCompleted: true,
            categoryID: healthCat.id,
            seriesID: workoutSeries.id,
            occurrenceOriginalDate: fixedCalendar.startOfDay(for: mon)
        )
        let ovTue = TimeBlock(
            title: "Treino",
            startDate: makeDate(year: 2026, month: 11, day: 24, hour: 7),
            endDate: makeDate(year: 2026, month: 11, day: 24, hour: 8),
            isCompleted: true,
            categoryID: healthCat.id,
            seriesID: workoutSeries.id,
            occurrenceOriginalDate: fixedCalendar.startOfDay(for: tue)
        )
        let ovWed = TimeBlock(
            title: "Treino",
            startDate: makeDate(year: 2026, month: 11, day: 25, hour: 7),
            endDate: makeDate(year: 2026, month: 11, day: 25, hour: 8),
            isCompleted: true,
            categoryID: healthCat.id,
            seriesID: workoutSeries.id,
            occurrenceOriginalDate: fixedCalendar.startOfDay(for: wed)
        )

        let report = InsightsEngine.generate(
            period: .week,
            offset: 0,
            blocks: [session1, session2, ovMon, ovTue, ovWed],
            seriesList: [workoutSeries],
            notes: [globalProject],
            categories: [workCat, healthCat],
            referenceDate: thu,
            calendar: fixedCalendar
        )

        // Global block has 2 sessions = 240 min total (120 completed)
        #expect(report.globalBlocksMinutes == 240)
        #expect(report.globalBlockStats.count == 1)
        #expect(report.globalBlockStats.first?.totalMinutes == 240)
        #expect(report.globalBlockStats.first?.completedSessionCount == 1)

        // 7 daily workout occurrences (420 min) + 2 Atlas sessions (240 min) = 660 min
        #expect(report.totalPlannedMinutes == 660)
        #expect(report.totalBlocksCount == 9)
        #expect(report.completedBlocksCount == 4)

        // Active streak is 3 (Mon, Tue, Wed completed; Thu still in progress today doesn't break it)
        #expect(report.bestCurrentStreak == 3)
        #expect(report.routineStreaks.first?.currentStreak == 3)
        #expect(report.routineStreaks.first?.bestStreak == 3)
    }

    @Test("ReminderScheduler generates upcoming reminder candidates skipping completed and past blocks")
    func reminderCandidateFiltering() {
        let now = makeDate(year: 2026, month: 11, day: 23, hour: 10)
        let upcoming = TimeBlock(
            title: "Reunião importante",
            startDate: makeDate(year: 2026, month: 11, day: 23, hour: 11),
            endDate: makeDate(year: 2026, month: 11, day: 23, hour: 12),
            reminderMinutesBefore: 10
        )
        let completed = TimeBlock(
            title: "Já concluído",
            startDate: makeDate(year: 2026, month: 11, day: 23, hour: 12),
            endDate: makeDate(year: 2026, month: 11, day: 23, hour: 13),
            isCompleted: true,
            reminderMinutesBefore: 10
        )
        let past = TimeBlock(
            title: "Passado",
            startDate: makeDate(year: 2026, month: 11, day: 23, hour: 8),
            endDate: makeDate(year: 2026, month: 11, day: 23, hour: 9),
            reminderMinutesBefore: 10
        )

        let candidates = ReminderScheduler.upcomingReminderCandidates(
            blocks: [upcoming, completed, past],
            seriesList: [],
            notes: [],
            categories: [],
            now: now,
            daysAhead: 2,
            calendar: fixedCalendar
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.title == "Reunião importante")
        #expect(candidates.first?.fireDate == upcoming.startDate.addingTimeInterval(-10 * 60))
    }
}
