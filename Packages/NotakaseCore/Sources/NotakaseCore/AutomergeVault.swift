import Automerge
import Foundation

/// Reads and writes the notes tree as per-note Automerge documents inside a
/// sync folder — one `note_<id>.automerge` file per note, matching the format
/// the Linux/CLI clients use. The `.automerge` bytes are the source of truth;
/// there is no parallel markdown on disk.
///
/// Document schema (ROOT map), as produced by the other clients:
///   body:     Text    — markdown content (a collaborative string, so char-level
///                        edits from different devices merge)
///   path:     String  — repo-relative path, e.g. `Journal/2026-07-13.md`
///   created:  Int      — ms since the Unix epoch
///   modified: Int      — ms since the Unix epoch
///   deleted:  Boolean  — tombstone; hidden here but kept so deletes propagate
///   version:  Int      — schema version (currently 1)
///
/// Writes are load-modify-save on the existing on-disk document: we splice the
/// `body` Text and never rewrite `path` for an existing note, so a note the
/// Linux client filed at a deep path (`a/b/c/d.md`) keeps that path even though
/// our tree only surfaces two levels.
public enum AutomergeVault {
    static let filePrefix = "note_"
    static let fileExt = "automerge"
    static let schemaVersion: Int64 = 1

    public struct Loaded {
        public let notes: [Note]
        public let folders: [String]
    }

    // MARK: - Reading

    public static func load(from root: URL) throws -> Loaded {
        let fm = FileManager.default
        let entries =
            (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        let files =
            entries
            .filter(isNoteFile)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var notes: [Note] = []
        var folders: [String] = []
        for file in files {
            guard let data = try? Data(contentsOf: file),
                let doc = try? Document(data)
            else { continue }
            if (try? boolValue(doc, "deleted")) == true { continue }

            let path = nonEmpty(try? stringValue(doc, "path")) ?? file.lastPathComponent
            let body = (try? textValue(doc, "body")) ?? ""
            let modified = try? intValue(doc, "modified")

            let dir = dirComponents(forPath: path)
            let fname = fileName(forPath: path)
            let slug =
                fname.lowercased().hasSuffix(".md") ? String(fname.dropLast(3)) : fname
            let updated =
                modified.flatMap { $0 }.map { MarkdownVault.relativeUpdated(msToDate($0)) }
                ?? "just now"

            notes.append(
                Note(
                    id: noteID(from: file), dir: dir,
                    title: MarkdownVault.title(fromBody: body, fallback: slug),
                    slug: slug, updated: updated, body: body))
            if let top = dir.first, !folders.contains(top) { folders.append(top) }
        }
        return Loaded(notes: notes, folders: folders)
    }

    // MARK: - Writing

    /// Upsert a note's `.automerge` document. Loads the existing file (so
    /// remote history and the stored `path` are preserved) and splices in the
    /// new body; creates a fresh document with a full schema when absent.
    public static func write(note: Note, to root: URL) throws {
        let file = fileURL(for: note.id, in: root)
        let doc: Document
        let isNew: Bool
        if let data = try? Data(contentsOf: file), let existing = try? Document(data) {
            doc = existing
            isNew = false
        } else {
            doc = Document()
            isNew = true
        }

        let textObj: ObjId
        if case let .some(.Object(id, .Text)) = try doc.get(obj: .ROOT, key: "body") {
            textObj = id
        } else {
            textObj = try doc.putObject(obj: .ROOT, key: "body", ty: .Text)
        }
        // updateText diffs against the current value, so concurrent edits from
        // another device merge instead of clobbering.
        try doc.updateText(obj: textObj, value: note.body)

        let now = nowMS()
        if isNew {
            try doc.put(
                obj: .ROOT, key: "path",
                value: .String(relativePath(for: note)))
            try doc.put(obj: .ROOT, key: "created", value: .Int(now))
            try doc.put(obj: .ROOT, key: "version", value: .Int(schemaVersion))
            try doc.put(obj: .ROOT, key: "deleted", value: .Boolean(false))
        }
        try doc.put(obj: .ROOT, key: "modified", value: .Int(now))

        try doc.save().write(to: file, options: .atomic)
    }

    /// Create a new note (seeded with title + date) at an arbitrary-depth
    /// folder path and return its model.
    @discardableResult
    public static func createNote(
        in root: URL, dir: [String], title: String
    ) throws -> Note {
        let slug = MarkdownVault.slugify(title)
        let note = Note(
            id: newID(), dir: dir, title: title, slug: slug,
            updated: "just now",
            body: "# \(title)\n\n\(MarkdownVault.todayString())\n\n")
        try write(note: note, to: root)
        return note
    }

    /// Two-level convenience over ``createNote(in:dir:title:)``.
    @discardableResult
    public static func createNote(
        in root: URL, folder: String, sub: String? = nil, title: String
    ) throws -> Note {
        try createNote(in: root, dir: sub.map { [folder, $0] } ?? [folder], title: title)
    }

    /// Move a note to a new folder path by rewriting its stored `path`
    /// (keeping the same file name). Unlike ``write(note:to:)``, this
    /// deliberately changes `path`. A `dir` of `[]` files it at the top level.
    public static func move(
        noteID id: String, to dir: [String], fileName: String, in root: URL
    ) throws {
        let file = fileURL(for: id, in: root)
        guard let data = try? Data(contentsOf: file), let doc = try? Document(data) else {
            return
        }
        let newPath = (dir + [fileName]).joined(separator: "/")
        try doc.put(obj: .ROOT, key: "path", value: .String(newPath))
        try doc.put(obj: .ROOT, key: "modified", value: .Int(nowMS()))
        try doc.save().write(to: file, options: .atomic)
    }

    /// Tombstone a note so the deletion propagates to other devices.
    public static func delete(noteID id: String, in root: URL) throws {
        let file = fileURL(for: id, in: root)
        guard let data = try? Data(contentsOf: file), let doc = try? Document(data) else {
            return
        }
        try doc.put(obj: .ROOT, key: "deleted", value: .Boolean(true))
        try doc.put(obj: .ROOT, key: "modified", value: .Int(nowMS()))
        try doc.save().write(to: file, options: .atomic)
    }

    /// Write the built-in seed notes into an empty folder (first-run content).
    public static func seed(into root: URL) throws {
        for note in SeedData.notes { try write(note: note, to: root) }
    }

    // MARK: - Identity & paths

    /// A fresh note id: 16 random bytes, base64url without padding (22 chars) —
    /// the same shape the Linux/CLI clients generate.
    public static func newID() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in bytes.indices { bytes[i] = UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func isNoteFile(_ url: URL) -> Bool {
        url.pathExtension == fileExt && url.lastPathComponent.hasPrefix(filePrefix)
    }

    static func noteID(from file: URL) -> String {
        String(file.deletingPathExtension().lastPathComponent.dropFirst(filePrefix.count))
    }

    static func fileURL(for id: String, in root: URL) -> URL {
        root.appendingPathComponent("\(filePrefix)\(id).\(fileExt)")
    }

    /// The on-disk relative path for a note (arbitrary depth). Used only when
    /// creating a new document — an existing note keeps its stored path.
    static func relativePath(for note: Note) -> String {
        (note.dir + [note.fileName]).joined(separator: "/")
    }

    /// The folder components of a stored path, at any depth. A path with no
    /// directory (a root-level file) has no components — it's a loose note that
    /// lives at the top level until filed into a folder.
    static func dirComponents(forPath path: String) -> [String] {
        let comps = path.split(separator: "/").map(String.init)
        return comps.count > 1 ? Array(comps.dropLast()) : []
    }

    /// The final path component (the file name).
    static func fileName(forPath path: String) -> String {
        path.split(separator: "/").map(String.init).last ?? path
    }

    // MARK: - Automerge accessors

    private static func textValue(_ doc: Document, _ key: String) throws -> String {
        if case let .some(.Object(id, .Text)) = try doc.get(obj: .ROOT, key: key) {
            return try doc.text(obj: id)
        }
        return ""
    }
    private static func stringValue(_ doc: Document, _ key: String) throws -> String {
        if case let .some(.Scalar(.String(s))) = try doc.get(obj: .ROOT, key: key) { return s }
        return ""
    }
    private static func boolValue(_ doc: Document, _ key: String) throws -> Bool {
        if case let .some(.Scalar(.Boolean(b))) = try doc.get(obj: .ROOT, key: key) { return b }
        return false
    }
    private static func intValue(_ doc: Document, _ key: String) throws -> Int64? {
        if case let .some(.Scalar(.Int(i))) = try doc.get(obj: .ROOT, key: key) { return i }
        return nil
    }

    // MARK: - Time

    static func nowMS() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    static func msToDate(_ ms: Int64) -> Date {
        Date(timeIntervalSince1970: Double(ms) / 1000)
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        return s
    }
}
