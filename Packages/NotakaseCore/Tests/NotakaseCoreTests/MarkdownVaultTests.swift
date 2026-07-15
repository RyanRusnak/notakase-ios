import XCTest

@testable import NotakaseCore

final class MarkdownVaultTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("nk-vault-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testSeedThenLoadRoundTrips() throws {
        try MarkdownVault.seed(into: root)
        let loaded = try MarkdownVault.load(from: root)
        XCTAssertEqual(loaded.notes.count, SeedData.notes.count)
        // Folders discovered from disk match the seed's folders.
        XCTAssertEqual(Set(loaded.folders), Set(SeedData.folderOrder))
    }

    func testPathMapping() throws {
        // folder / sub / file structure
        try write("Daily/2026-07-13.md", "# Thursday\n\nbody")
        try write("Projects/guides/deep.md", "# Deep\n\nx")
        try write("loose.md", "# Loose\n\ny")  // root file → "Notes"

        let loaded = try MarkdownVault.load(from: root)
        let byId = Dictionary(
            uniqueKeysWithValues: loaded.notes.map { ($0.id, $0) })

        let daily = try XCTUnwrap(byId["Daily/2026-07-13.md"])
        XCTAssertEqual(daily.folder, "Daily")
        XCTAssertNil(daily.sub)
        XCTAssertEqual(daily.title, "Thursday")  // from the H1
        XCTAssertEqual(daily.slug, "2026-07-13")

        let deep = try XCTUnwrap(byId["Projects/guides/deep.md"])
        XCTAssertEqual(deep.folder, "Projects")
        XCTAssertEqual(deep.sub, "guides")

        let loose = try XCTUnwrap(byId["loose.md"])
        XCTAssertEqual(loose.folder, "Notes")
    }

    func testTitleFallsBackToSlug() throws {
        try write("Notes/no-heading.md", "just a paragraph, no heading")
        let loaded = try MarkdownVault.load(from: root)
        let n = try XCTUnwrap(loaded.notes.first { $0.id == "Notes/no-heading.md" })
        XCTAssertEqual(n.title, "no-heading")
    }

    func testCreateNoteWritesFile() throws {
        let note = try MarkdownVault.createNote(
            in: root, folder: "Daily", title: "My New Note")
        XCTAssertEqual(note.folder, "Daily")
        XCTAssertEqual(note.slug, "my-new-note")
        XCTAssertEqual(note.id, "Daily/my-new-note.md")

        let onDisk = root.appendingPathComponent("Daily/my-new-note.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: onDisk.path))
        let reloaded = try MarkdownVault.load(from: root)
        XCTAssertTrue(reloaded.notes.contains { $0.id == "Daily/my-new-note.md" })
    }

    func testWriteUpdatesBodyOnDisk() throws {
        var note = try MarkdownVault.createNote(
            in: root, folder: "Daily", title: "Edit Me")
        note = Note(
            id: note.id, folder: note.folder, title: note.title,
            slug: note.slug, updated: note.updated, body: "# Edit Me\n\nchanged")
        try MarkdownVault.write(note: note, to: root)

        let contents = try String(
            contentsOf: root.appendingPathComponent("Daily/edit-me.md"),
            encoding: .utf8)
        XCTAssertTrue(contents.contains("changed"))
    }

    func testCreateFolderMakesDirectory() throws {
        try MarkdownVault.createFolder(in: root, name: "Ideas")
        var isDir: ObjCBool = false
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent("Ideas").path,
                isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
        // An empty folder still shows up as a folder on load.
        let loaded = try MarkdownVault.load(from: root)
        XCTAssertTrue(loaded.folders.contains("Ideas"))
    }

    // MARK: helper
    private func write(_ relPath: String, _ body: String) throws {
        let url = root.appendingPathComponent(relPath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data(body.utf8).write(to: url)
    }
}
