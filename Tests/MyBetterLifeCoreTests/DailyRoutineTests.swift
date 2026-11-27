import Foundation
import Testing
@testable import MyBetterLifeCore

@Suite("DailyRoutineItem & PlannerStore Routine Persistence")
struct DailyRoutineTests {

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test("Weekday masks filter applicable days and format summaries accurately")
    func weekdayMaskFilteringAndSummaries() {
        // 2026-11-27 is Friday, 2026-11-28 is Saturday, 2026-11-29 is Sunday, 2026-11-30 is Monday
        let friday = makeDate(year: 2026, month: 11, day: 27)
        let saturday = makeDate(year: 2026, month: 11, day: 28)
        let sunday = makeDate(year: 2026, month: 11, day: 29)
        let monday = makeDate(year: 2026, month: 11, day: 30)

        let everyDay = DailyRoutineItem(title: "Tomar água", weekdaysMask: .all)
        #expect(everyDay.applies(to: friday))
        #expect(everyDay.applies(to: saturday))
        #expect(everyDay.applies(to: sunday))
        #expect(everyDay.scheduleSummary == nil)

        let weekdaysOnly = DailyRoutineItem(title: "Revisar e-mails", weekdaysMask: .weekdays)
        #expect(weekdaysOnly.applies(to: friday))
        #expect(weekdaysOnly.applies(to: monday))
        #expect(!weekdaysOnly.applies(to: saturday))
        #expect(!weekdaysOnly.applies(to: sunday))
        #expect(weekdaysOnly.scheduleSummary == "Seg–Sex")

        let weekendOnly = DailyRoutineItem(title: "Planejar semana", weekdaysMask: .weekend)
        #expect(weekendOnly.applies(to: saturday))
        #expect(weekendOnly.applies(to: sunday))
        #expect(!weekendOnly.applies(to: friday))
        #expect(weekendOnly.scheduleSummary == "Fins de sem.")

        let custom = DailyRoutineItem(title: "Academia", weekdaysMask: [.monday, .friday])
        #expect(custom.applies(to: monday))
        #expect(custom.applies(to: friday))
        #expect(!custom.applies(to: saturday))
        #expect(custom.scheduleSummary == "Seg, Sex")
    }

    @MainActor
    @Test("Completion history is isolated per calendar day and persists across toggles")
    func perDayCompletionHistory() {
        let store = PlannerStore(inMemory: true)
        let item = DailyRoutineItem(title: "Ler 20 minutos", estimatedMinutes: 20)
        store.upsertRoutineItem(item)

        let day1 = makeDate(year: 2026, month: 11, day: 26)
        let day2 = makeDate(year: 2026, month: 11, day: 27)

        #expect(!store.isRoutineCompleted(item.id, on: day1))
        #expect(!store.isRoutineCompleted(item.id, on: day2))

        // Mark completed on day1 — day2 remains unchecked
        let newState = store.toggleRoutineCompletion(itemID: item.id, on: day1)
        #expect(newState == true)
        #expect(store.isRoutineCompleted(item.id, on: day1) == true)
        #expect(store.isRoutineCompleted(item.id, on: day2) == false)

        // Toggle back off on day1
        let toggledOff = store.toggleRoutineCompletion(itemID: item.id, on: day1)
        #expect(toggledOff == false)
        #expect(store.isRoutineCompleted(item.id, on: day1) == false)
    }

    @MainActor
    @Test("TimeBlock routineItemID persists and deleting a routine soft-deletes it without removing scheduled blocks")
    func routineBlockLinkAndSoftDelete() {
        let store = PlannerStore(inMemory: true)
        let category = BlockCategory(name: "Saúde", colorHex: "#10B981")
        store.upsertCategory(category)

        let item = DailyRoutineItem(title: "Correr 5km", estimatedMinutes: 45, categoryID: category.id)
        store.upsertRoutineItem(item)

        let day = makeDate(year: 2026, month: 11, day: 27)
        let block = TimeBlock(
            title: item.title,
            startDate: day,
            endDate: day.addingTimeInterval(45 * 60),
            categoryID: category.id,
            routineItemID: item.id
        )
        store.upsertBlock(block)

        #expect(store.block(for: block.id)?.routineItemID == item.id)

        // Deleting category clears routine's categoryID
        store.deleteCategory(id: category.id)
        #expect(store.routineItem(for: item.id)?.categoryID == nil)

        // Deleting routine removes it from active list, keeps tombstone in snapshot, and preserves past block
        store.deleteRoutineItem(id: item.id)
        #expect(store.routineItem(for: item.id) == nil)
        #expect(store.block(for: block.id) != nil)
        let snapshot = store.syncSnapshot()
        #expect(snapshot.routineItems.first(where: { $0.id == item.id })?.deletedAt != nil)
    }

    @MainActor
    @Test("Remote LWW sync merges routine items and completions")
    func remoteSyncMergesRoutinesAndCompletions() {
        let store = PlannerStore(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let t1 = t0.addingTimeInterval(60)

        let item = DailyRoutineItem(title: "Meditar", updatedAt: t0)
        store.upsertRoutineItem(item)

        var newerRemote = item
        newerRemote.title = "Meditar 15 min"
        newerRemote.updatedAt = t1

        let completion = DailyRoutineCompletion(
            routineItemID: item.id,
            dayKey: "2026-11-27",
            isCompleted: true,
            updatedAt: t1
        )

        store.applyRemoteSync(
            categories: [],
            blocks: [],
            series: [],
            notes: [],
            attachments: [],
            inboxItems: [],
            routineItems: [newerRemote],
            routineCompletions: [completion]
        )

        #expect(store.routineItem(for: item.id)?.title == "Meditar 15 min")
        let day = makeDate(year: 2026, month: 11, day: 27)
        #expect(store.isRoutineCompleted(item.id, on: day) == true)
    }
}
