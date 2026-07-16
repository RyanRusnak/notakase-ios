import Foundation

public struct KeyRow: Identifiable {
    public let id = UUID()
    public let keys: [String]
    public let action: String
    public init(keys: [String], action: String) {
        self.keys = keys
        self.action = action
    }
}

public struct KeyGroup: Identifiable {
    public let id = UUID()
    public let title: String
    public let rows: [KeyRow]
    public init(title: String, rows: [KeyRow]) {
        self.title = title
        self.rows = rows
    }
}

public enum Shortcuts {
    public static let groups: [KeyGroup] = [
        KeyGroup(
            title: "Navigate",
            rows: [
                KeyRow(keys: ["j", "k"], action: "Move selection down / up"),
                KeyRow(keys: ["g", "G"], action: "Jump to top / bottom"),
                KeyRow(keys: ["l", "→"], action: "Expand folder"),
                KeyRow(keys: ["h"], action: "Collapse folder / go to parent"),
                KeyRow(keys: ["↵"], action: "Open folder, or open the note"),
            ]),
        KeyGroup(
            title: "Notes",
            rows: [
                KeyRow(keys: ["e"], action: "Edit selected note"),
                KeyRow(keys: ["a", "n"], action: "New note (seeded title + date)"),
                KeyRow(keys: ["r"], action: "Rename / move selected note"),
                KeyRow(keys: ["s"], action: "Send note to a folder"),
                KeyRow(keys: ["d"], action: "Delete selected note (confirms)"),
            ]),
        KeyGroup(
            title: "Find",
            rows: [
                KeyRow(keys: ["⌘", "P"], action: "Fuzzy-find a note by path"),
                KeyRow(keys: ["⌘", "K"], action: "Command palette & quick switch"),
                KeyRow(keys: ["/"], action: "Full-text search across notes"),
            ]),
        KeyGroup(
            title: "Read & modes",
            rows: [
                KeyRow(keys: ["J", "K"], action: "Scroll the preview"),
                KeyRow(keys: ["⌘", "F"], action: "Page-scroll the preview"),
                KeyRow(keys: ["i", "e"], action: "Enter write mode"),
                KeyRow(keys: ["Esc"], action: "Back to read mode"),
                KeyRow(keys: ["Tab"], action: "Zen mode (hide the tree)"),
            ]),
        KeyGroup(
            title: "App",
            rows: [
                KeyRow(keys: ["t"], action: "Cycle Omarchy theme"),
                KeyRow(keys: ["?"], action: "This shortcuts sheet"),
                KeyRow(keys: ["⌘", "Q"], action: "Quit"),
            ]),
    ]
}
