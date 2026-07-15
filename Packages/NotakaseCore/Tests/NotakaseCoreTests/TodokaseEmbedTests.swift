import XCTest

@testable import NotakaseCore

final class TodokaseEmbedTests: XCTestCase {
    func testParseKeyValues() {
        let e = TodokaseEmbed.parse("project: notakase\nstatus: done")
        XCTAssertEqual(e.project, "notakase")
        XCTAssertEqual(e.status, .done)
    }

    func testDefaultsToOpen() {
        let e = TodokaseEmbed.parse("project: notakase")
        XCTAssertEqual(e.status, .open)
    }

    func testBareLineIsProjectShorthand() {
        let e = TodokaseEmbed.parse("notakase")
        XCTAssertEqual(e.project, "notakase")
        XCTAssertEqual(e.status, .open)
    }

    func testUnknownStatusFallsBackToOpen() {
        XCTAssertEqual(TodokaseEmbed.parse("project: x\nstatus: bogus").status, .open)
    }

    func testEmptyHasNoProject() {
        XCTAssertNil(TodokaseEmbed.parse("").project)
    }

    // MARK: filter

    private let projects = [
        TodokaseProject(id: "p1", name: "notakase"),
        TodokaseProject(id: "p2", name: "todokase"),
    ]
    private let tasks = [
        TodokaseTask(id: "a", listId: "p1", title: "open one", done: false, created: 1),
        TodokaseTask(id: "b", listId: "p1", title: "done one", done: true, created: 2),
        TodokaseTask(id: "c", listId: "p2", title: "other project", done: false, created: 3),
    ]

    func testFilterOpenByProjectNameCaseInsensitive() {
        let r = TodokaseTasks.filter(
            tasks: tasks, projects: projects, project: "Notakase", status: .open)
        XCTAssertEqual(r.map(\.id), ["a"])
    }

    func testFilterDone() {
        let r = TodokaseTasks.filter(
            tasks: tasks, projects: projects, project: "notakase", status: .done)
        XCTAssertEqual(r.map(\.id), ["b"])
    }

    func testFilterAllOrderedByCreated() {
        let r = TodokaseTasks.filter(
            tasks: tasks, projects: projects, project: "notakase", status: .all)
        XCTAssertEqual(r.map(\.id), ["a", "b"])
    }

    func testUnknownProjectIsEmpty() {
        XCTAssertTrue(
            TodokaseTasks.filter(
                tasks: tasks, projects: projects, project: "nope", status: .all
            ).isEmpty)
    }
}
