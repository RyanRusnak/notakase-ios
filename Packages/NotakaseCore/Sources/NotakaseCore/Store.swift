import Foundation
import SwiftUI

/// Shared, observable app state: the notes, the folder list and the active theme.
/// Platform-specific view state (view mode, active block, palette) lives in each app.
@MainActor
public final class NotakaseStore: ObservableObject {
    @Published public var notes: [Note]
    @Published public var folders: [String]
    @Published public var themeName: ThemeName
    /// Set by a `notakase://` deep link; observed by the UI to open that note.
    @Published public var pendingOpenNoteID: String?
    /// The sync folder currently backing the notes, if any. `nil` = in-memory seed.
    @Published public private(set) var folderURL: URL?

    // MARK: - Sync health
    /// When the last folder sync (read from disk) last succeeded.
    @Published public private(set) var lastSyncedAt: Date?
    /// The error from the most recent failed sync, cleared on success.
    @Published public private(set) var lastSyncError: String?

    /// The traffic-light state shown by the sync health dot.
    public enum SyncHealth: Equatable { case unknown, ok, failing }
    public var syncHealth: SyncHealth {
        guard folderURL != nil else { return .unknown }
        if lastSyncError != nil { return .failing }
        return lastSyncedAt != nil ? .ok : .unknown
    }

    /// One-line status used for the health dot's hover tooltip.
    public var syncStatusDescription: String {
        guard folderURL != nil else { return "Local only — no sync folder" }
        if let err = lastSyncError { return "Sync failed: \(err)" }
        if let ts = lastSyncedAt {
            return "Last synced " + ts.formatted(date: .abbreviated, time: .shortened)
        }
        return "Not synced yet"
    }

    /// Watches the sync folder so notes added on other devices appear here.
    private var watcher: FolderWatcher?

    public init(themeName: ThemeName = .tokyonight) {
        self.notes = SeedData.notes
        self.folders = SeedData.folderOrder
        self.themeName = themeName
    }

    public var theme: Theme { Theme.named(themeName) }

    public var folderOrder: [String] { folders }

    public func note(id: String) -> Note? { notes.first { $0.id == id } }

    public func note(title: String) -> Note? {
        notes.first { $0.title.lowercased() == title.lowercased() }
    }

    /// Handle a `notakase://wiki/<title>` deep link by requesting that note open.
    public func handleDeepLink(_ url: URL) {
        guard let title = WikiLink.title(from: url),
            let n = note(title: title)
        else { return }
        pendingOpenNoteID = n.id
    }

    public func notes(inFolder folder: String) -> [Note] {
        notes.filter { $0.folder == folder }
    }

    // MARK: - Sync folder backing

    /// Point the store at a sync folder (or `nil` to revert to in-memory seed).
    /// Loads `.md` files from the folder; seeds it first if it has none.
    public func applySyncFolder(_ url: URL?) {
        watcher?.stop()
        watcher = nil
        guard let url else {
            if folderURL != nil {
                folderURL = nil
                notes = SeedData.notes
                folders = SeedData.folderOrder
                lastSyncedAt = nil
                lastSyncError = nil
            }
            return
        }
        folderURL = url
        reloadFromDisk(seedIfEmpty: true)
        // Re-read whenever the sync daemon drops in / removes note files.
        watcher = FolderWatcher(url: url) { [weak self] in
            Task { @MainActor in self?.reloadFromDisk() }
        }
    }

    /// Thrown when the sync folder is gone or unreadable (unmounted drive,
    /// undownloaded iCloud folder, stale bookmark) — surfaced as a red dot.
    struct SyncFolderUnreachable: LocalizedError {
        var errorDescription: String? { "folder is unavailable" }
    }

    /// Re-read the backing folder from disk, recording sync health for the UI.
    public func reloadFromDisk(seedIfEmpty: Bool = false) {
        guard let url = folderURL else { return }
        do {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(
                atPath: url.path(percentEncoded: false), isDirectory: &isDir),
                isDir.boolValue
            else { throw SyncFolderUnreachable() }
            var loaded = try AutomergeVault.load(from: url)
            if loaded.notes.isEmpty && seedIfEmpty {
                try AutomergeVault.seed(into: url)
                loaded = try AutomergeVault.load(from: url)
            }
            notes = loaded.notes
            folders = loaded.folders.isEmpty ? SeedData.folderOrder : loaded.folders
            lastSyncedAt = Date()
            lastSyncError = nil
        } catch {
            lastSyncError = error.localizedDescription
            #if DEBUG
            print("Notakase: couldn't load sync folder: \(error)")
            #endif
        }
    }

    /// Manually trigger a sync (folder re-read). No-op when local-only.
    public func syncNow() { reloadFromDisk() }

    public func setTheme(_ name: ThemeName) { themeName = name }

    public func cycleTheme() {
        let i = Theme.order.firstIndex(of: themeName) ?? 0
        themeName = Theme.order[(i + 1) % Theme.order.count]
    }

    public static func today() -> String {
        let d = Date()
        let c = Calendar.current.dateComponents(
            [.year, .month, .day], from: d)
        return String(
            format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Create a note seeded with a title + date at an arbitrary-depth folder
    /// path, insert it, and return it. When folder-backed, it's written to disk.
    @discardableResult
    public func addNote(dir: [String], title: String) -> Note {
        if let url = folderURL,
            let note = try? AutomergeVault.createNote(in: url, dir: dir, title: title)
        {
            notes.append(note)
            if let top = dir.first, !folders.contains(top) { folders.append(top) }
            return note
        }
        let id = "new-" + UUID().uuidString.prefix(8)
        let note = Note(
            id: String(id), dir: dir, title: title,
            updated: "just now",
            body: "# \(title)\n\n\(Self.today())\n\n")
        notes.append(note)
        return note
    }

    /// Two-level convenience over ``addNote(dir:title:)``.
    @discardableResult
    public func addNote(folder: String, title: String) -> Note {
        addNote(dir: [folder], title: title)
    }

    /// Add a top-level folder if it does not already exist. Folders live in the
    /// notes' `path` fields rather than on disk, so an empty one is in-memory
    /// only until its first note is created.
    public func addFolder(_ name: String) {
        guard !folders.contains(name) else { return }
        folders.append(name)
    }

    /// Replace a note's body (used by the iOS inline editor). Writes to disk
    /// when folder-backed.
    public func updateBody(id: String, _ body: String) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].body = body
        notes[i].updated = "just now"
        if let url = folderURL {
            try? AutomergeVault.write(note: notes[i], to: url)
        }
    }
}
