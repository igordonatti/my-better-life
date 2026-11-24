import Foundation
import Testing
@testable import MyBetterLifeCore

@Suite("NotesLibraryEngine")
@MainActor
struct NotesLibraryEngineTests {
    @Test("Filters by origin, hides empty agenda blocks, filters by day, and pins notes first")
    func originDayAndPinFiltering() {
        let store = PlannerStore(inMemory: true)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let day1 = cal.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 10))!
        let day2 = cal.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 10))!

        let workCat = BlockCategory(name: "Trabalho", colorHex: "#3B82F6")
        store.upsertCategory(workCat)

        // Standalone pinned note on day 1
        let pinnedNote = StandaloneNote(
            title: "To-do Principal",
            noteMarkdown: "- [ ] Tarefa A",
            isPinned: true,
            categoryID: workCat.id,
            createdAt: day1,
            updatedAt: day1
        )
        store.upsertNote(pinnedNote)

        // Standalone unpinned note on day 2
        let quickNote = StandaloneNote(
            title: "Ideia rápida",
            noteMarkdown: "Anotação solta",
            isPinned: false,
            createdAt: day2,
            updatedAt: day2
        )
        store.upsertNote(quickNote)

        // Agenda block WITH note on day 1
        let agendaWithNote = TimeBlock(
            title: "Reunião Arquitetura",
            startDate: day1,
            endDate: day1.addingTimeInterval(3600),
            noteMarkdown: "## Decisões\n- Usar Core Data",
            categoryID: workCat.id
        )
        store.upsertBlock(agendaWithNote)

        // Agenda block WITHOUT note on day 1 (should be hidden from Notes library)
        let agendaEmpty = TimeBlock(
            title: "Almoço",
            startDate: day1.addingTimeInterval(7200),
            endDate: day1.addingTimeInterval(10800),
            noteMarkdown: "   "
        )
        store.upsertBlock(agendaEmpty)

        // 1. All origins: 2 standalone + 1 non-empty agenda = 3 items, pinned first
        let allItems = NotesLibraryEngine.items(
            notes: store.notes,
            blocks: store.blocks,
            categories: store.categories,
            attachments: store.attachments,
            originFilter: .all,
            calendar: cal
        )
        #expect(allItems.count == 3)
        #expect(allItems.first?.title == "To-do Principal")
        #expect(allItems.first?.isPinned == true)
        #expect(!allItems.contains(where: { $0.title == "Almoço" }))

        // 2. Standalone only (hides agenda notes!)
        let standaloneOnly = NotesLibraryEngine.items(
            notes: store.notes,
            blocks: store.blocks,
            categories: store.categories,
            attachments: store.attachments,
            originFilter: .standaloneOnly,
            calendar: cal
        )
        #expect(standaloneOnly.count == 2)
        #expect(standaloneOnly.allSatisfy { !$0.isFromAgenda })

        // 3. Agenda only
        let agendaOnly = NotesLibraryEngine.items(
            notes: store.notes,
            blocks: store.blocks,
            categories: store.categories,
            attachments: store.attachments,
            originFilter: .agendaOnly,
            calendar: cal
        )
        #expect(agendaOnly.count == 1)
        #expect(agendaOnly.first?.title == "Reunião Arquitetura")

        // 4. Filter by day 1 -> pinnedNote + agendaWithNote
        let day1Items = NotesLibraryEngine.items(
            notes: store.notes,
            blocks: store.blocks,
            categories: store.categories,
            attachments: store.attachments,
            originFilter: .all,
            filterDay: day1,
            calendar: cal
        )
        #expect(day1Items.count == 2)

        // 5. Global search finds standalone notes too
        let searchHits = SearchEngine.search(
            query: "solta",
            blocks: store.blocks,
            seriesList: store.seriesList,
            notes: store.notes,
            categories: store.categories,
            calendar: cal
        )
        #expect(searchHits.count == 1)
        #expect(searchHits.first?.note?.id == quickNote.id)
    }
}
