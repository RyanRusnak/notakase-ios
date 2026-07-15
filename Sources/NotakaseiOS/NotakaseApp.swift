import NotakaseCore
import SwiftUI

@main
struct NotakaseApp: App {
    @StateObject private var store = NotakaseStore()
    @StateObject private var syncFolder = SyncFolder()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(store)
                .environmentObject(syncFolder)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
                .onOpenURL { store.handleDeepLink($0) }
        }
    }
}

/// Shared helpers for the iOS presentation.
enum iOSHelpers {
    /// A one-line plain-text preview of a note body (heading stripped, markdown removed).
    static func snippet(_ note: Note) -> String {
        let blocks = Markdown.parse(note.body)
        for block in blocks {
            switch block {
            case .paragraph(let t, _):
                return plain(t)
            case .list(_, let items, _):
                if let first = items.first { return plain(first.content) }
            case .quote(let t, _):
                return plain(t)
            default:
                continue
            }
        }
        return ""
    }

    private static func plain(_ s: String) -> String {
        s.replacingOccurrences(
            of: "[*`\\[\\]()#>]", with: "", options: .regularExpression
        )
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespaces)
    }

    /// A short status tag for a note card, if any.
    static func tag(_ note: Note) -> String? {
        if note.folder == "notakase.dev" { return "site" }
        let open = Markdown.parse(note.body).reduce(0) { acc, block in
            if case .list(_, let items, _) = block {
                return acc + items.filter { $0.task == false }.count
            }
            return acc
        }
        return open > 0 ? "\(open) task\(open == 1 ? "" : "s")" : nil
    }

    static func barColor(for note: Note, indexInGroup: Int, theme: Theme) -> Color {
        if indexInGroup > 0 { return theme.faintColor }
        switch note.folder {
        case "Daily": return theme.accentColor
        case "Notes": return theme.magentaColor
        case "Projects": return theme.orangeColor
        default: return theme.accent2Color
        }
    }
}
