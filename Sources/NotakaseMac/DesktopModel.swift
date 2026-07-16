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
    @Published var activeBlock = 0
    @Published var search = ""
    /// The whole-note markdown being edited in Write mode.
    @Published var draft = ""
    /// Selection cursor in the sidebar tree (index into the selectable rows).
    @Published var treeSel = 0
    /// Set true to ask the sidebar to focus its search field (from `/`).
    @Published var focusSearch = false
    /// Zen mode hides the sidebar tree (Tab).
    @Published var zen = false
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

    // MARK: - Sidebar tree rows

    /// A flattened, display-ordered sidebar row. The model owns this so both
    /// rendering and keyboard navigation work off the same list.
    enum SidebarRow: Identifiable, Equatable {
        case folder(path: [String], glyph: String, depth: Int, open: Bool, count: Int)
        case note(note: Note, depth: Int)
        case input(kind: Creating.Kind, depth: Int, placeholder: String)

        var id: String {
            switch self {
            case .folder(let p, _, _, _, _): return "f:" + p.joined(separator: "/")
            case .note(let n, _): return "n:" + n.id
            case .input(_, let d, _): return "i:\(d)"
            }
        }
        var isSelectable: Bool {
            if case .input = self { return false }
            return true
        }
    }

    /// The whole visible tree, in render order (loose notes, then folders
    /// recursively, plus any in-progress creation input row).
    func visibleRows() -> [SidebarRow] {
        let q = search.lowercased().trimmingCharacters(in: .whitespaces)
        func match(_ n: Note) -> Bool {
            q.isEmpty || (n.title + " " + n.body).lowercased().contains(q)
        }
        let visible = q.isEmpty ? store.notes : store.notes.filter(match)
        var rows: [SidebarRow] = []

        for n in visible where n.dir.isEmpty {
            rows.append(.note(note: n, depth: 0))
        }
        var tops = store.folderOrder
        for t in visible.compactMap({ $0.dir.first }) where !tops.contains(t) {
            tops.append(t)
        }
        for top in tops {
            appendFolder(path: [top], visible: visible, depth: 0, q: q, into: &rows)
        }
        if creating?.kind == .folder {
            rows.append(.input(kind: .folder, depth: 0, placeholder: "folder-name…"))
        }
        return rows
    }

    private func appendFolder(
        path: [String], visible: [Note], depth: Int, q: String,
        into rows: inout [SidebarRow]
    ) {
        let below = visible.filter {
            $0.dir.count >= path.count && Array($0.dir.prefix(path.count)) == path
        }
        let creatingHere = creating?.kind == .note && creating?.parent == path
        if !q.isEmpty && below.isEmpty && !creatingHere { return }

        let key = path.joined(separator: "/")
        let open = q.isEmpty ? !collapsed.contains(key) : true
        let glyph = depth == 0 ? (SeedData.folderGlyph[path[0]] ?? "▤") : "▤"
        rows.append(
            .folder(path: path, glyph: glyph, depth: depth, open: open, count: below.count))
        guard open else { return }

        if creatingHere {
            rows.append(.input(kind: .note, depth: depth + 1, placeholder: "Untitled note…"))
        }
        for n in below where n.dir == path {
            rows.append(.note(note: n, depth: depth + 1))
        }
        var childNames: [String] = []
        for n in below where n.dir.count > path.count {
            let child = n.dir[path.count]
            if !childNames.contains(child) { childNames.append(child) }
        }
        for child in childNames.sorted() {
            appendFolder(path: path + [child], visible: visible, depth: depth + 1, q: q, into: &rows)
        }
    }

    var selectableRows: [SidebarRow] { visibleRows().filter(\.isSelectable) }

    // MARK: - Tree navigation (vim h/j/k/l + enter)

    private func openIfNote(_ row: SidebarRow) {
        if case .note(let n, _) = row { openId = n.id }
    }

    /// j / k — move the selection, previewing notes as you land on them.
    func treeMove(_ delta: Int) {
        let rows = selectableRows
        guard !rows.isEmpty else { return }
        treeSel = max(0, min(rows.count - 1, treeSel + delta))
        openIfNote(rows[treeSel])
    }

    /// l — expand a folder / open a note.
    func treeExpandOrOpen() {
        let rows = selectableRows
        guard rows.indices.contains(treeSel) else { return }
        switch rows[treeSel] {
        case .folder(let path, _, _, let open, _):
            if !open { collapsed.remove(path.joined(separator: "/")) }
        case .note(let n, _):
            openNote(n.id)
        case .input:
            break
        }
    }

    /// h — collapse a folder, or jump to the parent folder.
    func treeCollapseOrParent() {
        let rows = selectableRows
        guard rows.indices.contains(treeSel) else { return }
        switch rows[treeSel] {
        case .folder(let path, _, _, let open, _):
            if open {
                collapsed.insert(path.joined(separator: "/"))
            } else {
                selectFolder(Array(path.dropLast()))
            }
        case .note(let n, _):
            selectFolder(n.dir)
        case .input:
            break
        }
    }

    /// enter — open the selected note or toggle the selected folder.
    func treeActivate() {
        let rows = selectableRows
        guard rows.indices.contains(treeSel) else { return }
        switch rows[treeSel] {
        case .folder(let path, _, _, _, _):
            toggleFolder(path.joined(separator: "/"))
        case .note(let n, _):
            openNote(n.id)
        case .input:
            break
        }
    }

    /// Sync the keyboard cursor to a row the user clicked.
    func selectRow(_ row: SidebarRow) {
        if let i = selectableRows.firstIndex(where: { $0.id == row.id }) { treeSel = i }
    }

    private func selectFolder(_ path: [String]) {
        guard !path.isEmpty else { return }
        let rows = selectableRows
        if let i = rows.firstIndex(where: {
            if case .folder(let p, _, _, _, _) = $0 { return p == path }
            return false
        }) {
            treeSel = i
        }
    }

    // MARK: - Editing (full-note Write mode)

    func enterEdit() {
        draft = current.body
        setView(.edit)
    }

    func commitEdit() {
        if view == .edit, draft != current.body {
            store.updateBody(id: openId, draft)
        }
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
            activeBlock = 0
            selectNote(note.id)  // move the tree cursor onto the new note
            enterEdit()          // …and drop straight into its body
        }
    }

    /// Move the tree selection cursor onto a note by id.
    func selectNote(_ id: String) {
        if let i = selectableRows.firstIndex(where: {
            if case .note(let n, _) = $0 { return n.id == id }
            return false
        }) {
            treeSel = i
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
            // A text field/editor has focus. Esc leaves it; in Write mode that
            // also commits the draft and returns to Read. Everything else
            // (typing, backspace) passes through to the field.
            if code == KeyCode.escape {
                if view == .edit {
                    commitEdit()
                    setView(.read)
                }
                NSApp.keyWindow?.makeFirstResponder(nil)
                return true
            }
            return false
        }
        switch chars {
        case "i", "e": enterEdit(); return true
        case "a", "n": startNote(); return true
        case "s": openSendTo(); return true
        case "t": cycleTheme(); return true
        case "/": focusSearch = true; return true
        case "j": treeMove(1); return true
        case "k": treeMove(-1); return true
        case "h": treeCollapseOrParent(); return true
        case "l": treeExpandOrOpen(); return true
        case "?": keysOpen = true; return true
        default:
            switch code {
            case KeyCode.ret: treeActivate(); return true
            case KeyCode.tab: zen.toggle(); return true
            case KeyCode.escape: setView(.read); return true
            default: return false
            }
        }
    }
}
