import XCTest

@testable import NotakaseCore

@MainActor
final class SyncHealthTests: XCTestCase {
    private func makeTempFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("notakase-health-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: url, withIntermediateDirectories: true)
        return url
    }

    func testUnknownWhenLocalOnly() {
        let store = NotakaseStore()
        XCTAssertEqual(store.syncHealth, .unknown)
        XCTAssertNil(store.lastSyncedAt)
        XCTAssertEqual(store.syncStatusDescription, "Local only — no sync folder")
    }

    func testSuccessfulSyncReportsOk() throws {
        let folder = try makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let store = NotakaseStore()
        store.applySyncFolder(folder)  // seeds + loads

        XCTAssertEqual(store.syncHealth, .ok)
        XCTAssertNotNil(store.lastSyncedAt)
        XCTAssertNil(store.lastSyncError)
        XCTAssertTrue(store.syncStatusDescription.hasPrefix("Last synced"))
    }

    func testFailedSyncReportsFailing() throws {
        let folder = try makeTempFolder()
        let store = NotakaseStore()
        store.applySyncFolder(folder)
        XCTAssertEqual(store.syncHealth, .ok)

        // Delete the folder out from under the store, then re-sync.
        try FileManager.default.removeItem(at: folder)
        store.syncNow()

        XCTAssertEqual(store.syncHealth, .failing)
        XCTAssertNotNil(store.lastSyncError)
        XCTAssertTrue(store.syncStatusDescription.hasPrefix("Sync failed"))
    }

    func testRevertingToLocalOnlyClearsStatus() throws {
        let folder = try makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let store = NotakaseStore()
        store.applySyncFolder(folder)
        XCTAssertEqual(store.syncHealth, .ok)

        store.applySyncFolder(nil)
        XCTAssertEqual(store.syncHealth, .unknown)
        XCTAssertNil(store.lastSyncedAt)
        XCTAssertNil(store.lastSyncError)
    }
}
