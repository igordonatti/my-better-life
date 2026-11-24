import Foundation
import Testing
@testable import MyBetterLifeCore

@Suite("SecondBrainEngine & Global Blocks")
@MainActor
struct SecondBrainEngineTests {
    @Test("Extracts [[wikilinks]], resolves backlinks, and tracks Global Block sessions across days")
    func globalBlockSharedLivingDocAndBacklinks() {
        let store = PlannerStore(inMemory: true)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let mon = cal.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 9))!
        let wed = cal.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 14))!

        // Create a Global Block
        var globalHub = StandaloneNote(
            title: "My Better Life",
            noteMarkdown: "# Roadmap\n- [ ] Criar [[Arquitetura Go]]",
            isGlobal: true
        )
        store.upsertNote(globalHub)

        // Child note referencing the Global Block
        let childNote = StandaloneNote(
            title: "Arquitetura Go",
            noteMarkdown: "Conectado a [[My Better Life]]\nUsar PostgreSQL + SSE."
        )
        store.upsertNote(childNote)

        // Schedule the Global Block on Monday and Wednesday
        let monBlock = TimeBlock(
            title: "My Better Life",
            startDate: mon,
            endDate: mon.addingTimeInterval(7200),
            globalNoteID: globalHub.id
        )
        let wedBlock = TimeBlock(
            title: "My Better Life",
            startDate: wed,
            endDate: wed.addingTimeInterval(3600),
            globalNoteID: globalHub.id
        )
        store.upsertBlock(monBlock)
        store.upsertBlock(wedBlock)

        // Edit the Global Block once -> BOTH Monday and Wednesday reflect the updated living document!
        globalHub.updateNoteMarkdown("# Roadmap\n- [x] Criar [[Arquitetura Go]]\n- [ ] Testar no iPhone")
        store.upsertNote(globalHub)

        let monOccs = RecurrenceEngine.occurrences(on: mon, blocks: store.blocks, seriesList: store.seriesList, notes: store.notes, calendar: cal)
        let wedOccs = RecurrenceEngine.occurrences(on: wed, blocks: store.blocks, seriesList: store.seriesList, notes: store.notes, calendar: cal)

        #expect(monOccs.count == 1)
        #expect(wedOccs.count == 1)
        #expect(monOccs[0].isGlobalLinked == true)
        #expect(monOccs[0].noteMarkdown.contains("Testar no iPhone"))
        #expect(wedOccs[0].noteMarkdown == monOccs[0].noteMarkdown)

        // Scheduled sessions history tracks both days
        let sessions = SecondBrainEngine.scheduledSessions(forGlobalNoteID: globalHub.id, blocks: store.blocks)
        #expect(sessions.count == 2)

        // Wiki-links & Backlinks work bidirectionally
        let outgoing = SecondBrainEngine.extractWikiLinks(from: globalHub.noteMarkdown)
        #expect(outgoing == ["Arquitetura Go"])

        let backlinksToGlobal = SecondBrainEngine.backlinks(
            forTitle: "My Better Life",
            excludingNoteID: globalHub.id,
            notes: store.notes,
            blocks: store.blocks,
            categories: store.categories
        )
        #expect(backlinksToGlobal.count == 1)
        #expect(backlinksToGlobal.first?.title == "Arquitetura Go")

        // Autocomplete query helper (both `[[` and `@`, ignoring email addresses)
        #expect(SecondBrainEngine.activeWikiLinkQuery(in: "Veja [[My Bet") == "My Bet")
        #expect(SecondBrainEngine.activeWikiLinkQuery(in: "Veja @Obser") == "Obser")
        #expect(SecondBrainEngine.activeWikiLinkQuery(in: "Email: igor@gmail.com") == nil)
        #expect(SecondBrainEngine.activeWikiLinkQuery(in: "Veja [[My Better Life]] ok") == nil)
        #expect(SecondBrainEngine.completeTrailingWikiLink(in: "Veja [[My Bet", with: "My Better Life") == "Veja [[My Better Life]] ")
        #expect(SecondBrainEngine.completeTrailingWikiLink(in: "Estudar @SLO", with: "SLO & Error Budget") == "Estudar [[SLO & Error Budget]] ")
    }

    @Test("Multi-level subnotes hierarchy, anti-cycle reparent guard, and automatic promotion on parent delete")
    func multiLevelSubnotesAndPromotion() {
        let store = PlannerStore(inMemory: true)

        let root = StandaloneNote(title: "Estudos de SRE", isGlobal: true)
        let k8s = StandaloneNote(title: "Kubernetes", parentNoteID: root.id)
        let networking = StandaloneNote(title: "Networking", parentNoteID: k8s.id)
        let slo = StandaloneNote(title: "SLO & Error Budget", parentNoteID: root.id)

        store.upsertNote(root)
        store.upsertNote(k8s)
        store.upsertNote(networking)
        store.upsertNote(slo)

        // Direct children & descendant counts
        #expect(SecondBrainEngine.childNotes(of: root.id, in: store.notes).count == 2)
        #expect(SecondBrainEngine.descendantCount(of: root.id, in: store.notes) == 3)

        // Ancestor breadcrumb path: Estudos de SRE -> Kubernetes (for Networking)
        let path = SecondBrainEngine.ancestorPath(for: networking, in: store.notes)
        #expect(path.map(\.title) == ["Estudos de SRE", "Kubernetes"])

        // Anti-cycle guard rejects moving root into itself or into its grandchild
        #expect(SecondBrainEngine.canReparent(noteID: root.id, toParentID: root.id, in: store.notes) == false)
        #expect(SecondBrainEngine.canReparent(noteID: root.id, toParentID: networking.id, in: store.notes) == false)
        #expect(SecondBrainEngine.canReparent(noteID: slo.id, toParentID: k8s.id, in: store.notes) == true)

        // Deleting intermediate parent ("Kubernetes") promotes "Networking" to "Estudos de SRE"
        store.deleteNote(id: k8s.id)
        #expect(store.note(for: k8s.id) == nil)
        #expect(store.note(for: networking.id)?.parentNoteID == root.id)
    }
}
