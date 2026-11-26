import Foundation
import Testing
@testable import MyBetterLifeCore

@Suite("ReminderScheduler")
struct ReminderSchedulerTests {
    private var fixedCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 9) -> Date {
        fixedCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
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
