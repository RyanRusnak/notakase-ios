import Foundation

/// Reads and writes the notes tree as plain `.md` files inside a sync folder.
///
/// Path → note mapping (Notakase supports one optional sub-folder level):
///   `<root>/<Folder>/note.md`            → folder=Folder, sub=nil
///   `<root>/<Folder>/<Sub>/note.md`      → folder=Folder, sub=Sub
///   `<root>/note.md`                     → folder="Notes", sub=nil
/// Deeper nesting is flattened onto the first two path components.
public enum MarkdownVault {
    public struct Loaded {
        public let notes: [Note]
        public let folders: [String]
    }

    // MARK: - Reading

    public static func load(from root: URL) throws -> Loaded {
        let fm = FileManager.default
        var folders: [String] = []

        // Top-level directories become folders even when empty.
        let topKeys: [URLResourceKey] = [.isDirectoryKey]
        if let top = try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: topKeys)
        {
            for url in top.sorted(by: { $0.path < $1.path }) {
                guard !url.lastPathComponent.hasPrefix(".") else { continue }
                let isDir =
                    (try? url.resourceValues(forKeys: [.isDirectoryKey]))?
                    .isDirectory ?? false
                if isDir && !folders.contains(url.lastPathComponent) {
                    folders.append(url.lastPathComponent)
                }
            }
        }

        // All markdown files, recursively.
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey]
        var files: [URL] = []
        if let en = fm.enumerator(at: root, includingPropertiesForKeys: keys) {
            for case let url as URL in en {
                guard !url.lastPathComponent.hasPrefix(".") else { continue }
                if url.pathExtension.lowercased() == "md" { files.append(url) }
            }
        }
        files.sort { $0.path < $1.path }

        var notes: [Note] = []
        for file in files {
            let rel = relativeComponents(of: file, base: root)
            guard !rel.isEmpty else { continue }
            let top: String
            let sub: String?
            let fname: String
            switch rel.count {
            case 1: (top, sub, fname) = ("Notes", nil, rel[0])
            case 2: (top, sub, fname) = (rel[0], nil, rel[1])
            default: (top, sub, fname) = (rel[0], rel[1], rel.last!)
            }
            let slug =
                fname.lowercased().hasSuffix(".md")
                ? String(fname.dropLast(3)) : fname
            let body = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            let modDate =
                (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? Date()
            let relPath = rel.joined(separator: "/")
            notes.append(
                Note(
                    id: relPath, folder: top, sub: sub,
                    title: title(fromBody: body, fallback: slug), slug: slug,
                    updated: relativeUpdated(modDate), body: body))
            if !folders.contains(top) { folders.append(top) }
        }

        return Loaded(notes: notes, folders: folders)
    }

    // MARK: - Writing

    /// Write a note's body to its file, creating intermediate directories.
    public static func write(note: Note, to root: URL) throws {
        let url = root.appendingPathComponent(relativePath(for: note))
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data(note.body.utf8).write(to: url, options: .atomic)
    }

    /// Create a new note file (seeded with title + date) and return its model.
    public static func createNote(
        in root: URL, folder: String, title: String
    ) throws -> Note {
        let slug = slugify(title)
        let id = folder + "/" + slug + ".md"
        let note = Note(
            id: id, folder: folder, title: title, slug: slug,
            updated: "just now",
            body: "# \(title)\n\n\(todayString())\n\n")
        try write(note: note, to: root)
        return note
    }

    /// Create an (empty) folder directory.
    public static func createFolder(in root: URL, name: String) throws {
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(name),
            withIntermediateDirectories: true)
    }

    /// Write the built-in seed notes into an empty folder (first-run content).
    public static func seed(into root: URL) throws {
        for note in SeedData.notes { try write(note: note, to: root) }
    }

    // MARK: - Helpers

    public static func relativePath(for note: Note) -> String {
        var comps = [note.folder]
        if let sub = note.sub { comps.append(sub) }
        comps.append(note.fileName)
        return comps.joined(separator: "/")
    }

    static func relativeComponents(of file: URL, base: URL) -> [String] {
        let baseC = base.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let fileC = file.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        guard fileC.count > baseC.count,
            Array(fileC.prefix(baseC.count)) == baseC
        else { return [file.lastPathComponent] }
        return Array(fileC.dropFirst(baseC.count))
    }

    static func title(fromBody body: String, fallback: String) -> String {
        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { continue }
            if t.hasPrefix("# ") {
                return String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
            break  // first non-empty line isn't an H1 — use the filename
        }
        return fallback
    }

    static func slugify(_ title: String) -> String {
        let s = title.lowercased().replacingOccurrences(
            of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        return s.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    static func todayString() -> String {
        let c = Calendar.current.dateComponents(
            [.year, .month, .day], from: Date())
        return String(
            format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func relativeUpdated(_ date: Date, now: Date = Date()) -> String {
        let secs = now.timeIntervalSince(date)
        if secs < 86400 { return "just now" }
        let days = Int(secs / 86400)
        if days == 1 { return "yesterday" }
        if days < 7 { return "\(days) days ago" }
        let weeks = days / 7
        if weeks == 1 { return "1 week ago" }
        if weeks < 5 { return "\(weeks) weeks ago" }
        let months = max(1, days / 30)
        return months == 1 ? "1 month ago" : "\(months) months ago"
    }
}
