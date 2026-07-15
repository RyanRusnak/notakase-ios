import Foundation

/// A single markdown note. Mirrors the design's note model.
public struct Note: Identifiable, Equatable, Hashable {
    public let id: String
    /// The note's folder location as path components, outermost first
    /// (`["Projects", "client", "2026"]`). Empty means the vault root. This
    /// supports arbitrary nesting depth.
    public var dir: [String]
    public var title: String
    /// Explicit publish slug; falls back to a slugified title.
    public var slug: String?
    public var updated: String
    public var body: String

    public init(
        id: String,
        dir: [String],
        title: String,
        slug: String? = nil,
        updated: String,
        body: String
    ) {
        self.id = id
        self.dir = dir
        self.title = title
        self.slug = slug
        self.updated = updated
        self.body = body
    }

    /// Back-compat convenience for the two-level `folder` / `sub` callers
    /// (seed data, shallow note creation, the legacy markdown vault).
    public init(
        id: String,
        folder: String,
        sub: String? = nil,
        title: String,
        slug: String? = nil,
        updated: String,
        body: String
    ) {
        self.init(
            id: id, dir: sub.map { [folder, $0] } ?? [folder],
            title: title, slug: slug, updated: updated, body: body)
    }

    /// The outermost folder (top level). A root-level note reports "Notes".
    public var folder: String { dir.first ?? "Notes" }
    /// The second-level folder, if the note is nested at least that deep.
    public var sub: String? { dir.count > 1 ? dir[1] : nil }
    /// The full folder path, slash-joined (empty at the vault root).
    public var folderPath: String { dir.joined(separator: "/") }

    /// `folder/slug.md`-style filename used in breadcrumbs and the status bar.
    public var fileName: String {
        let base =
            slug
            ?? title.lowercased()
                .replacingOccurrences(
                    of: "[^a-z0-9]+", with: "-",
                    options: .regularExpression
                )
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return base + ".md"
    }

    /// Approximate word count (matches the prototype's heuristic).
    public var wordCount: Int {
        let plain =
            body
            .replacingOccurrences(
                of: "[#>*`\\-\\[\\]()!]", with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "\\s+", with: " ", options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return plain.isEmpty ? 0 : plain.split(separator: " ").count
    }

    public var readMinutes: Int { max(1, Int(ceil(Double(wordCount) / 200.0))) }
}
