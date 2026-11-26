import Foundation
import Testing
@testable import MyBetterLifeCore

@Suite("MarkdownFormattingEngine")
struct MarkdownFormattingEngineTests {

    private func applyAndRender(
        _ action: MarkdownFormatAction,
        text: String,
        selection: NSRange
    ) -> (text: String, selection: NSRange) {
        let result = MarkdownFormattingEngine.apply(action, to: text, selection: selection)
        let mutable = NSMutableString(string: text)
        mutable.replaceCharacters(in: result.replaceRange, with: result.replacement)
        return (mutable as String, result.newSelection)
    }

    @Test("Bold wraps selected text and unwraps when toggled again")
    func boldWrapAndUnwrap() {
        let first = applyAndRender(.bold, text: "Estudar SRE hoje", selection: NSRange(location: 8, length: 3))
        #expect(first.text == "Estudar **SRE** hoje")
        #expect(first.selection == NSRange(location: 10, length: 3))

        let second = applyAndRender(.bold, text: first.text, selection: first.selection)
        #expect(second.text == "Estudar SRE hoje")
        #expect(second.selection == NSRange(location: 8, length: 3))
    }

    @Test("Bold with empty selection inserts pair and places cursor inside")
    func boldEmptySelection() {
        let res = applyAndRender(.bold, text: "Nota ", selection: NSRange(location: 5, length: 0))
        #expect(res.text == "Nota ****")
        #expect(res.selection == NSRange(location: 7, length: 0))
    }

    @Test("Italic wraps and unwraps without confusing bold markers")
    func italicDoesNotCollideWithBold() {
        let boldText = "**SRE**"
        // Selecting "SRE" inside **SRE** and pressing Italic should wrap into ***SRE***, not unwrap bold!
        let italicInsideBold = applyAndRender(.italic, text: boldText, selection: NSRange(location: 2, length: 3))
        #expect(italicInsideBold.text == "***SRE***")

        let normalItalic = applyAndRender(.italic, text: "texto", selection: NSRange(location: 0, length: 5))
        #expect(normalItalic.text == "*texto*")
        let unwrapped = applyAndRender(.italic, text: normalItalic.text, selection: normalItalic.selection)
        #expect(unwrapped.text == "texto")
    }

    @Test("Strikethrough and inline code toggle cleanly")
    func strikethroughAndCode() {
        let strike = applyAndRender(.strikethrough, text: "antigo", selection: NSRange(location: 0, length: 6))
        #expect(strike.text == "~~antigo~~")
        let unstrike = applyAndRender(.strikethrough, text: strike.text, selection: strike.selection)
        #expect(unstrike.text == "antigo")

        let code = applyAndRender(.inlineCode, text: "swift test", selection: NSRange(location: 0, length: 10))
        #expect(code.text == "`swift test`")
    }

    @Test("Checklist and Command+Return toggle checkbox state")
    func checklistAndCheckToggle() {
        let added = applyAndRender(.checklist, text: "Revisar alertas", selection: NSRange(location: 5, length: 0))
        #expect(added.text == "- [ ] Revisar alertas")

        let checked = applyAndRender(.toggleChecklistCheck, text: added.text, selection: added.selection)
        #expect(checked.text == "- [x] Revisar alertas")

        let unchecked = applyAndRender(.toggleChecklistCheck, text: checked.text, selection: checked.selection)
        #expect(unchecked.text == "- [ ] Revisar alertas")
    }

    @Test("Heading cycles ## -> ### -> # -> plain")
    func headingCycle() {
        let h2 = applyAndRender(.heading(level: nil), text: "Resumo", selection: NSRange(location: 6, length: 0))
        #expect(h2.text == "## Resumo")
        let h3 = applyAndRender(.heading(level: nil), text: h2.text, selection: h2.selection)
        #expect(h3.text == "### Resumo")
        let h1 = applyAndRender(.heading(level: nil), text: h3.text, selection: h3.selection)
        #expect(h1.text == "# Resumo")
        let plain = applyAndRender(.heading(level: nil), text: h1.text, selection: h1.selection)
        #expect(plain.text == "Resumo")
    }

    @Test("Link wraps selected text or URL intelligently")
    func linkInsertion() {
        let fromLabel = applyAndRender(.link, text: "Docs", selection: NSRange(location: 0, length: 4))
        #expect(fromLabel.text == "[Docs](https://)")
        #expect(fromLabel.selection == NSRange(location: 7, length: 8))

        let fromURL = applyAndRender(.link, text: "https://apple.com", selection: NSRange(location: 0, length: 17))
        #expect(fromURL.text == "[](https://apple.com)")
        #expect(fromURL.selection == NSRange(location: 1, length: 0))
    }
}
