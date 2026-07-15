import XCTest

@testable import NotakaseCore

final class MarkdownTests: XCTestCase {
    func testHeadingAndParagraph() {
        let blocks = Markdown.parse("# Title\n\nHello world")
        XCTAssertEqual(blocks.count, 2)
        guard case .heading(let level, let text, _) = blocks[0] else {
            return XCTFail("expected heading")
        }
        XCTAssertEqual(level, 1)
        XCTAssertEqual(text, "Title")
        guard case .paragraph(let p, _) = blocks[1] else {
            return XCTFail("expected paragraph")
        }
        XCTAssertEqual(p, "Hello world")
    }

    func testTaskList() {
        let blocks = Markdown.parse("- [x] done\n- [ ] todo")
        guard case .list(let ordered, let items, _) = blocks[0] else {
            return XCTFail("expected list")
        }
        XCTAssertFalse(ordered)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].task, true)
        XCTAssertEqual(items[0].content, "done")
        XCTAssertEqual(items[1].task, false)
    }

    func testOrderedList() {
        let blocks = Markdown.parse("1. one\n2. two")
        guard case .list(let ordered, let items, _) = blocks[0] else {
            return XCTFail("expected list")
        }
        XCTAssertTrue(ordered)
        XCTAssertEqual(items.map(\.content), ["one", "two"])
    }

    func testCodeFence() {
        let blocks = Markdown.parse("```bash\nls -la\n```")
        guard case .code(let lang, let text, _) = blocks[0] else {
            return XCTFail("expected code")
        }
        XCTAssertEqual(lang, "bash")
        XCTAssertEqual(text, "ls -la")
    }

    func testQuoteAndHr() {
        let blocks = Markdown.parse("> quoted line\n\n---")
        guard case .quote(let q, _) = blocks[0] else {
            return XCTFail("expected quote")
        }
        XCTAssertEqual(q, "quoted line")
        guard case .hr = blocks[1] else { return XCTFail("expected hr") }
    }

    func testInlineSpans() {
        let spans = Markdown.parseInline(
            "a **b** *c* `d` [[Wiki|W]] [x](http://y)")
        XCTAssertTrue(spans.contains(.bold("b")))
        XCTAssertTrue(spans.contains(.italic("c")))
        XCTAssertTrue(spans.contains(.code("d")))
        XCTAssertTrue(spans.contains(.wikiLink(target: "Wiki", label: "W")))
        XCTAssertTrue(spans.contains(.link(label: "x", href: "http://y")))
    }

    func testWordCount() {
        let note = Note(
            id: "t", folder: "F", title: "T", updated: "now",
            body: "# Heading\n\nsome words here")
        XCTAssertEqual(note.wordCount, 4)
    }

    func testSeedIntegrity() {
        XCTAssertEqual(SeedData.notes.count, 10)
        XCTAssertNotNil(SeedData.notes.first { $0.id == "daily-today" })
    }
}
