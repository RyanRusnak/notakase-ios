import XCTest

@testable import NotakaseCore

final class AutomergeVaultTests: XCTestCase {
    private func makeTempFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nk-amvault-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: identity + path mapping

    func testNewIDIsBase64URL22Chars() {
        let id = AutomergeVault.newID()
        XCTAssertEqual(id.count, 22)
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        XCTAssertTrue(id.unicodeScalars.allSatisfy { allowed.contains($0) })
    }

    func testPathMapsToFullDepthDir() {
        // A loose root file has no folder — it lives at the top level.
        XCTAssertEqual(AutomergeVault.dirComponents(forPath: "inbox.md"), [])
        XCTAssertEqual(AutomergeVault.fileName(forPath: "inbox.md"), "inbox.md")

        XCTAssertEqual(
            AutomergeVault.dirComponents(forPath: "Journal/2026-07-13.md"), ["Journal"])

        // Deep paths keep every component — no collapsing.
        let deep = "Projects/client/2026/q3/research/sources/paper.md"
        XCTAssertEqual(
            AutomergeVault.dirComponents(forPath: deep),
            ["Projects", "client", "2026", "q3", "research", "sources"])
        XCTAssertEqual(AutomergeVault.fileName(forPath: deep), "paper.md")
    }

    func testDeepNestingRoundTrips() throws {
        let root = try makeTempFolder()
        defer { try? FileManager.default.removeItem(at: root) }

        let dir = ["Projects", "client", "2026", "q3", "research"]
        let note = try AutomergeVault.createNote(in: root, dir: dir, title: "Findings")
        XCTAssertEqual(note.dir, dir)

        let loaded = try AutomergeVault.load(from: root)
        let got = try XCTUnwrap(loaded.notes.first { $0.id == note.id })
        XCTAssertEqual(got.dir, dir)
        // Only the outermost component is a "top-level" folder.
        XCTAssertEqual(loaded.folders, ["Projects"])
        // The stored path carries the full depth.
        XCTAssertEqual(got.folder, "Projects")
        XCTAssertEqual(got.sub, "client")
        XCTAssertEqual(got.folderPath, "Projects/client/2026/q3/research")
    }

    // MARK: round-trips

    func testCreateThenLoad() throws {
        let root = try makeTempFolder()
        defer { try? FileManager.default.removeItem(at: root) }

        let note = try AutomergeVault.createNote(in: root, folder: "Daily", title: "Hello Mac")
        // The file is named note_<id>.automerge.
        let file = AutomergeVault.fileURL(for: note.id, in: root)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        let loaded = try AutomergeVault.load(from: root)
        XCTAssertEqual(loaded.notes.count, 1)
        let got = try XCTUnwrap(loaded.notes.first)
        XCTAssertEqual(got.id, note.id)
        XCTAssertEqual(got.folder, "Daily")
        XCTAssertEqual(got.title, "Hello Mac")
        XCTAssertTrue(loaded.folders.contains("Daily"))
    }

    func testEditPreservesIdSubfolderAcrossWrites() throws {
        let root = try makeTempFolder()
        defer { try? FileManager.default.removeItem(at: root) }

        var note = try AutomergeVault.createNote(
            in: root, folder: "Projects", sub: "client", title: "Spec")
        // Edit the body and re-save through the existing document.
        note.body = "# Spec\n\nrewritten body\n"
        try AutomergeVault.write(note: note, to: root)

        let loaded = try AutomergeVault.load(from: root)
        let got = try XCTUnwrap(loaded.notes.first { $0.id == note.id })
        XCTAssertEqual(got.folder, "Projects")
        XCTAssertEqual(got.sub, "client")
        XCTAssertTrue(got.body.contains("rewritten body"))
    }

    func testMoveRewritesPathAndPersists() throws {
        let root = try makeTempFolder()
        defer { try? FileManager.default.removeItem(at: root) }

        // Start at the top level (no folder).
        let note = try AutomergeVault.createNote(in: root, dir: [], title: "Loose")
        XCTAssertEqual(try AutomergeVault.load(from: root).notes.first?.dir, [])

        // Move it into a nested folder.
        try AutomergeVault.move(
            noteID: note.id, to: ["Projects", "client"],
            fileName: note.fileName, in: root)

        let got = try XCTUnwrap(
            AutomergeVault.load(from: root).notes.first { $0.id == note.id })
        XCTAssertEqual(got.dir, ["Projects", "client"])

        // And back to the top level.
        try AutomergeVault.move(
            noteID: note.id, to: [], fileName: got.fileName, in: root)
        let back = try AutomergeVault.load(from: root).notes.first { $0.id == note.id }
        XCTAssertEqual(back?.dir, [])
    }

    func testDeletedNotesAreHidden() throws {
        let root = try makeTempFolder()
        defer { try? FileManager.default.removeItem(at: root) }

        let note = try AutomergeVault.createNote(in: root, folder: "Daily", title: "Temp")
        XCTAssertEqual(try AutomergeVault.load(from: root).notes.count, 1)

        try AutomergeVault.delete(noteID: note.id, in: root)
        // The file still exists (tombstone) but the note is hidden.
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: AutomergeVault.fileURL(for: note.id, in: root).path))
        XCTAssertEqual(try AutomergeVault.load(from: root).notes.count, 0)
    }

    func testSeedPopulatesFolder() throws {
        let root = try makeTempFolder()
        defer { try? FileManager.default.removeItem(at: root) }

        try AutomergeVault.seed(into: root)
        let loaded = try AutomergeVault.load(from: root)
        XCTAssertEqual(loaded.notes.count, SeedData.notes.count)
        XCTAssertFalse(loaded.folders.isEmpty)
    }
}
