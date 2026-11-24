import Foundation
import Testing
@testable import MyBetterLifeCore

@Suite("CommandPaletteEngine")
struct CommandPaletteEngineTests {
    private var fixedCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        fixedCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: 10))!
    }

    @Test("Parses Portuguese relative dates, weekdays, offsets, and dd/MM strings")
    func parsesPortugueseDates() {
        // 2026-11-23 is a Monday (weekday == 2)
        let ref = makeDate(year: 2026, month: 11, day: 23)

        let hoje = CommandPaletteEngine.parseDateIntent("hoje", referenceDate: ref, calendar: fixedCalendar)
        #expect(hoje == fixedCalendar.startOfDay(for: ref))

        let amanha = CommandPaletteEngine.parseDateIntent("amanhã", referenceDate: ref, calendar: fixedCalendar)
        #expect(amanha == fixedCalendar.startOfDay(for: makeDate(year: 2026, month: 11, day: 24)))

        let ontem = CommandPaletteEngine.parseDateIntent("ontem", referenceDate: ref, calendar: fixedCalendar)
        #expect(ontem == fixedCalendar.startOfDay(for: makeDate(year: 2026, month: 11, day: 22)))

        let sexta = CommandPaletteEngine.parseDateIntent("sexta", referenceDate: ref, calendar: fixedCalendar)
        #expect(sexta == fixedCalendar.startOfDay(for: makeDate(year: 2026, month: 11, day: 27)))

        let offset = CommandPaletteEngine.parseDateIntent("+3", referenceDate: ref, calendar: fixedCalendar)
        #expect(offset == fixedCalendar.startOfDay(for: makeDate(year: 2026, month: 11, day: 26)))

        let explicit = CommandPaletteEngine.parseDateIntent("05/12", referenceDate: ref, calendar: fixedCalendar)
        #expect(explicit == fixedCalendar.startOfDay(for: makeDate(year: 2026, month: 12, day: 5)))
    }

    @Test("Prioritizes Global Blocks, matches diacritic-insensitive actions, and offers Inbox capture")
    func ranksPaletteResults() {
        let global = StandaloneNote(title: "Arquitetura Go", noteMarkdown: "Backend e sync", isGlobal: true)
        let inbox = InboxItem(title: "Revisar arquitetura da API", estimatedMinutes: 45)
        let ref = makeDate(year: 2026, month: 11, day: 23)

        let results = CommandPaletteEngine.results(
            query: "arquitetura",
            blocks: [],
            seriesList: [],
            notes: [global],
            inboxItems: [inbox],
            categories: [],
            referenceDate: ref,
            calendar: fixedCalendar
        )

        #expect(results.contains(where: { item in
            if case .globalBlock(let n) = item.payload { return n.id == global.id }
            return false
        }))
        #expect(results.contains(where: { item in
            if case .inboxItem(let t) = item.payload { return t.id == inbox.id }
            return false
        }))
        #expect(results.contains(where: { item in
            if case .quickCaptureInbox(let text) = item.payload { return text == "arquitetura" }
            return false
        }))

        // Diacritic-insensitive quick action search
        let focusHits = CommandPaletteEngine.results(
            query: "pomodoro",
            blocks: [],
            seriesList: [],
            notes: [],
            inboxItems: [],
            categories: [],
            referenceDate: ref,
            calendar: fixedCalendar
        )
        #expect(focusHits.contains(where: { item in
            if case .action(.focusCurrentOrSelectedBlock) = item.payload { return true }
            return false
        }))
    }
}
