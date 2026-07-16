import AppKit
import Combine
import NotakaseCore
import SwiftUI

/// All macOS view state + interactions, centralised the way the prototype's
/// component class was. Reads/writes shared data through `NotakaseStore`.
@MainActor
final class DesktopModel: ObservableObject {
    let store: NotakaseStore
    private var cancellable: AnyCancellable?

    @Published var openId = "daily-today"
    @Published var view: ViewMode = .read
    @Published var insertMode = false
    @Published var activeBlock = 2
    @Published var search = ""
    @Published var paletteOpen = false
    @Published var pq = ""
    @Published var selIndex = 0
    @Published var themePickerOpen = false
    @Published var keysOpen = false
    @Published var collapsed: Set<String> = []
    // Send-to overlay (move the open note to a folder), opened with `s`.
    @Published var sendToOpen = false
    @Published var sendToQuery = ""
    @Published var sendToSel = 0

    struct Creating: Equatable {
        enum Kind { case note, folder }
        let kind: Kind
        /// Target folder path (outermost first). Empty = top level.
        let parent: [String]
    }
    @Published var creating: Creating?
    @Published var createValue = ""

    init(store: NotakaseStore) {
        self.store = store
        // Re-publish when shared store data changes (notes, theme).
        cancellable = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: derived
    var current: Note { store.note(id: openId) ?? store.notes[0] }
    var blocks: [Block] { Markdown.parse(current.body) }
    var theme: Theme { store.theme }

    // MARK: navigation
    func openNote(_ id: String) {
        openId = id
        activeBlock = 0
        paletteOpen = false
    }

    func openByTitle(_ title: String) {
        if let n = store.note(title: title) {
            openId = n.id
            activeBlock = 0
            paletteOpen = false
        }
    }

    func setView(_ v: ViewMode) {
        view = v
        paletteOpen = false
    }

    func setTheme(_ name: ThemeName) {
        store.setTheme(name)
        paletteOpen = false
        themePickerOpen = false
    }

    func cycleTheme() { store.cycleTheme() }

    func togglePalette() {
        paletteOpen.toggle()
        pq = ""
        selIndex = 0
    }

    // MARK: send-to (move the open note)
    func label(forDir dir: [String]) -> String {
        dir.isEmpty ? "Top level" : dir.joined(separator: " / ")
    }

    /// Destinations for the open note: top level + every folder, minus the
    /// note's current folder, filtered by the query.
    func sendToDestinations() -> [[String]] {
        let q = sendToQuery.lowercased().trimmingCharacters(in: .whitespaces)
        let cur = current.dir
        return ([[]] + store.folderPaths)
            .filter { $0 != cur }
            .filter { q.isEmpty || label(forDir: $0).lowercased().contains(q) }
    }

    func openSendTo() {
        sendToQuery = ""
        sendToSel = 0
        sendToOpen = true
    }

    func sendCurrentTo(_ dir: [String]) {
        store.moveNote(id: openId, to: dir)
        sendToOpen = false
    }

    func toggleFolder(_ path: String) {
        if collapsed.contains(path) {
            collapsed.remove(path)
        } else {
            collapsed.insert(path)
        }
    }

    func moveBlock(_ d: Int) {
        let len = blocks.count
        activeBlock = max(0, min(len - 1, activeBlock + d))
    }

    // MARK: create
    func startNote() {
        // New note lands in the folder of the note you're looking at (at any
        // depth), falling back to the first top-level folder.
        let dir = store.note(id: openId)?.dir ?? []
        let parent = dir.isEmpty ? [store.folderOrder.first ?? "Daily"] : dir
        creating = Creating(kind: .note, parent: parent)
        createValue = ""
        collapsed.remove(parent.joined(separator: "/"))
    }

    func startFolder() {
        creating = Creating(kind: .folder, parent: [])
        createValue = ""
    }

    func cancelCreate() {
        creating = nil
        createValue = ""
    }

    func commitCreate() {
        guard let c = creating else { return }
        let name = createValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return cancelCreate() }
        switch c.kind {
        case .folder:
            if store.folderOrder.contains(name) { return cancelCreate() }
            store.addFolder(name)
            collapsed.remove(name)
            creating = nil
            createValue = ""
        case .note:
            let dir = c.parent.isEmpty ? [store.folderOrder.first ?? "Daily"] : c.parent
            let note = store.addNote(dir: dir, title: name)
            creating = nil
            createValue = ""
            openId = note.id
            view = .edit
            activeBlock = 0
        }
    }

    // MARK: palette
    func paletteItems() -> [PaletteItem] {
        let q = pq.lowercased().trimmingCharacters(in: .whitespaces)
        var items: [PaletteItem] = store.notes.map { n in
            PaletteItem(icon: "¶", label: n.title, hint: n.folder) {
                [weak self] in self?.openNote(n.id)
            }
        }
        items += [
            PaletteItem(icon: "✎", label: "Switch to Edit", hint: "view") {
                [weak self] in self?.setView(.edit)
            },
            PaletteItem(icon: "◉", label: "Switch to Read", hint: "view") {
                [weak self] in self?.setView(.read)
            },
        ]
        if store.folderURL != nil {
            items.append(
                PaletteItem(icon: "⟳", label: "Sync now", hint: "sync") {
                    [weak self] in
                    self?.store.syncNow()
                    self?.paletteOpen = false
                })
        }
        items += Theme.order.map { id in
            PaletteItem(icon: "◐", label: "Theme: \(Theme.named(id).label)", hint: "theme") {
                [weak self] in self?.setTheme(id)
            }
        }
        if !q.isEmpty {
            items = items.filter {
                ($0.label + " " + $0.hint).lowercased().contains(q)
            }
        }
        return items
    }

    // MARK: keyboard
    static func isEditingText() -> Bool {
        NSApp.keyWindow?.firstResponder is NSTextView
    }

    /// Returns true if the key was handled (swallowed).
    func handleKey(_ e: NSEvent) -> Bool {
        let chars = e.charactersIgnoringModifiers ?? ""
        let cmd = e.modifierFlags.contains(.command)
        let code = e.keyCode

        if cmd && chars.lowercased() == "k" {
            togglePalette()
            return true
        }
        if keysOpen {
            if code == KeyCode.escape || chars == "?" {
                keysOpen = false
                return true
            }
            return false
        }
        if paletteOpen {
            let items = paletteItems()
            switch code {
            case KeyCode.escape:
                paletteOpen = false
                return true
            case KeyCode.arrowDown:
                selIndex = min(items.count - 1, selIndex + 1)
                return true
            case KeyCode.arrowUp:
                selIndex = max(0, selIndex - 1)
                return true
            case KeyCode.ret:
                let idx = min(selIndex, items.count - 1)
                if items.indices.contains(idx) { items[idx].action() }
                return true
            default:
                return false
            }
        }
        if sendToOpen {
            let dests = sendToDestinations()
            switch code {
            case KeyCode.escape:
                sendToOpen = false
                return true
            case KeyCode.arrowDown:
                sendToSel = min(dests.count - 1, sendToSel + 1)
                return true
            case KeyCode.arrowUp:
                sendToSel = max(0, sendToSel - 1)
                return true
            case KeyCode.ret:
                let idx = min(sendToSel, dests.count - 1)
                if dests.indices.contains(idx) { sendCurrentTo(dests[idx]) }
                return true
            default:
                return false
            }
        }
        if Self.isEditingText() {
            if code == KeyCode.escape {
                NSApp.keyWindow?.makeFirstResponder(nil)
                return true
            }
            return false
        }
        switch chars {
        case "i", "e": setView(.edit); insertMode = true; return true
        case "s": openSendTo(); return true
        case "t": cycleTheme(); return true
        case "j": moveBlock(1); return true
        case "k": moveBlock(-1); return true
        case "?": keysOpen = true; return true
        default:
            if code == KeyCode.escape {
                // Esc leaves write mode and returns to read (vim normal).
                setView(.read)
                insertMode = false
                return true
            }
            return false
        }
    }
}
