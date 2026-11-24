import Foundation
import Testing
@testable import MyBetterLifeCore

@Suite("RichNoteDocument")
struct RichNoteDocumentTests {
    @Test("Parses headings, checklists, bullets, images, and paragraphs")
    func parsesRichMarkdown() {
        let imgID = UUID()
        let md = """
        # Plano da Manhã
        - [x] Café da manhã
        - [ ] Revisar PRs
        - Ponto solto
        ![Quadro](attachment://\(imgID.uuidString))
        Veja https://apple.com e [Docs](https://developer.apple.com).
        """
        let lines = RichNoteDocument.parseLines(from: md)
        #expect(lines.count == 6)
        #expect(lines[0] == .heading(id: 0, level: 1, text: "Plano da Manhã"))
        #expect(lines[1] == .checklist(id: 1, isChecked: true, text: "Café da manhã"))
        #expect(lines[2] == .checklist(id: 2, isChecked: false, text: "Revisar PRs"))
        #expect(lines[3] == .bullet(id: 3, text: "Ponto solto"))
        #expect(lines[4] == .image(id: 4, attachmentID: imgID, caption: "Quadro"))

        let summary = RichNoteDocument.summarize(markdown: md)
        #expect(summary.checklist == ChecklistStats(completed: 1, total: 2))
        #expect(summary.imageCount == 1)
        #expect(summary.linkCount == 2)
        #expect(summary.previewText == "Plano da Manhã")
        #expect(summary.plainTextIndex.contains("Revisar PRs"))
    }

    @Test("Toggles checklist item in place")
    func togglesChecklist() {
        let md = """
        # Tarefas
        - [ ] Comprar café
        - [x] Ler livro
        """
        let toggled = RichNoteDocument.toggleChecklist(at: 1, in: md)
        let lines = RichNoteDocument.parseLines(from: toggled)
        #expect(lines[1] == .checklist(id: 1, isChecked: true, text: "Comprar café"))
        #expect(lines[2] == .checklist(id: 2, isChecked: true, text: "Ler livro"))
    }
}
