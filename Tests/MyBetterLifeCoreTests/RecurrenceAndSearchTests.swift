import Foundation
import Testing
@testable import MyBetterLifeCore

@Suite("RecurrenceEngine & SearchEngine")
@MainActor
struct RecurrenceAndSearchTests {
    @Test("Recurring series expands on matching days and keeps per-day overrides independent")
    func recurrenceAndOverrides() {
        let store = PlannerStore(inMemory: true)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = cal.date(from: DateComponents(year: 2026, month: 11, day: 23))! // Monday
        let tuesday = cal.date(byAdding: .day, value: 1, to: monday)!
        let saturday = cal.date(byAdding: .day, value: 5, to: monday)!

        let series = RecurrenceSeries(
            title: "Treino",
            ruleType: .weekdays,
            weekdaysMask: .weekdays,
            startMinuteOfDay: 7 * 60,
            durationMinutes: 60,
            templateMarkdown: "- [ ] Aquecimento\n- [ ] Série principal",
            seriesStartDate: monday
        )
        store.upsertSeries(series)

        // Occurs on Monday & Tuesday, NOT on Saturday
        #expect(RecurrenceEngine.seriesOccurs(series, on: monday, calendar: cal))
        #expect(RecurrenceEngine.seriesOccurs(series, on: tuesday, calendar: cal))
        #expect(!RecurrenceEngine.seriesOccurs(series, on: saturday, calendar: cal))

        // Materialize override on Monday and edit its checklist
        var mondayOverride = RecurrenceEngine.materializeOverride(for: series, on: monday, in: store, calendar: cal)
        mondayOverride.updateNoteMarkdown("- [x] Aquecimento\n- [x] Série principal\nCorrida 5km!")
        mondayOverride.isCompleted = true
        store.upsertBlock(mondayOverride)

        let mondayItems = RecurrenceEngine.occurrences(
            on: monday,
            blocks: store.blocks,
            seriesList: store.seriesList,
            categories: store.categories,
            attachments: store.attachments,
            calendar: cal
        )
        let tuesdayItems = RecurrenceEngine.occurrences(
            on: tuesday,
            blocks: store.blocks,
            seriesList: store.seriesList,
            categories: store.categories,
            attachments: store.attachments,
            calendar: cal
        )

        #expect(mondayItems.count == 1)
        #expect(mondayItems[0].isCompleted == true)
        #expect(mondayItems[0].noteMarkdown.contains("Corrida 5km!"))

        // Tuesday stays clean with the inherited template!
        #expect(tuesdayItems.count == 1)
        #expect(tuesdayItems[0].isCompleted == false)
        #expect(tuesdayItems[0].isVirtualOccurrence == true)
        #expect(!tuesdayItems[0].noteMarkdown.contains("Corrida 5km!"))

        // Global search finds the per-day note
        let searchHits = SearchEngine.search(
            query: "corrida",
            blocks: store.blocks,
            seriesList: store.seriesList,
            categories: store.categories,
            calendar: cal
        )
        #expect(searchHits.count == 1)
        #expect(searchHits[0].title == "Treino")
        #expect(searchHits[0].snippet.contains("Corrida 5km!"))
    }

    @Test("Deleting only a single occurrence hides that day without removing the series")
    func deleteSingleOccurrenceOverride() {
        let store = PlannerStore(inMemory: true)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = cal.date(from: DateComponents(year: 2026, month: 11, day: 23))!
        let tuesday = cal.date(byAdding: .day, value: 1, to: monday)!

        let series = RecurrenceSeries(
            title: "Daily Standup",
            ruleType: .daily,
            startMinuteOfDay: 10 * 60,
            durationMinutes: 30,
            seriesStartDate: monday
        )
        store.upsertSeries(series)

        var mondayOverride = RecurrenceEngine.materializeOverride(for: series, on: monday, in: store, calendar: cal)
        mondayOverride.isDeletedOverride = true
        store.upsertBlock(mondayOverride)

        let mondayItems = RecurrenceEngine.occurrences(on: monday, blocks: store.blocks, seriesList: store.seriesList, calendar: cal)
        let tuesdayItems = RecurrenceEngine.occurrences(on: tuesday, blocks: store.blocks, seriesList: store.seriesList, calendar: cal)

        #expect(mondayItems.isEmpty)
        #expect(tuesdayItems.count == 1)
        #expect(tuesdayItems[0].title == "Daily Standup")
    }

    @Test("Converting standalone block with image attachment into recurring series clones template attachment")
    func convertStandaloneWithAttachmentToSeries() {
        let store = PlannerStore(inMemory: true)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = cal.date(from: DateComponents(year: 2026, month: 11, day: 23))!
        let tuesday = cal.date(byAdding: .day, value: 1, to: monday)!

        var block = TimeBlock(
            title: "Revisão Visual",
            startDate: TimelineMath.date(on: monday, minuteOfDay: 9 * 60, calendar: cal),
            endDate: TimelineMath.date(on: monday, minuteOfDay: 10 * 60, calendar: cal)
        )
        let att = BlockAttachment(
            fileName: "quadro.png",
            mimeType: "image/png",
            imageData: Data([0x89, 0x50, 0x4E, 0x47]),
            blockID: block.id
        )
        store.upsertAttachment(att)
        block.updateNoteMarkdown(RichNoteDocument.appendImageReference(attachmentID: att.id, to: "# Notas"), attachmentCount: 1)
        store.upsertBlock(block)

        let series = RecurrenceEngine.convertToRecurringSeries(
            block: block,
            ruleType: .daily,
            weekdaysMask: .all,
            in: store,
            calendar: cal
        )

        #expect(store.attachments(forSeriesID: series.id).count == 1)
        let tuesdayItems = RecurrenceEngine.occurrences(
            on: tuesday,
            blocks: store.blocks,
            seriesList: store.seriesList,
            categories: store.categories,
            attachments: store.attachments,
            calendar: cal
        )
        #expect(tuesdayItems.count == 1)
        #expect(tuesdayItems[0].attachmentCount == 1)
    }
}
