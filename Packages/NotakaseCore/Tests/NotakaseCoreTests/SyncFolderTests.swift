import XCTest

@testable import NotakaseCore

@MainActor
final class SyncFolderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "notakase.syncFolderBookmark")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "notakase.syncFolderBookmark")
        super.tearDown()
    }

    private func makeTempFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("notakase-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: url, withIntermediateDirectories: true)
        return url
    }

    func testDefaultsToNoFolder() {
        let sf = SyncFolder()
        XCTAssertFalse(sf.isSet)
        XCTAssertNil(sf.folderURL)
        XCTAssertEqual(sf.displayPath, "No folder selected")
    }

    func testSetFolderPersistsAndRestores() throws {
        let folder = try makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let sf = SyncFolder()
        sf.setFolder(folder)
        XCTAssertTrue(sf.isSet)
        XCTAssertEqual(sf.folderName, folder.lastPathComponent)

        // A fresh instance should resolve the saved bookmark.
        let restored = SyncFolder()
        XCTAssertTrue(restored.isSet)
        XCTAssertEqual(
            restored.folderURL?.standardizedFileURL,
            folder.standardizedFileURL)
    }

    func testClearFolder() throws {
        let folder = try makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let sf = SyncFolder()
        sf.setFolder(folder)
        XCTAssertTrue(sf.isSet)
        sf.clearFolder()
        XCTAssertFalse(sf.isSet)

        // And it stays cleared for a new instance.
        XCTAssertFalse(SyncFolder().isSet)
    }
}
