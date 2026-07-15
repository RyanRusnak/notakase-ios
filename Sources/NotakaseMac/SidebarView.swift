import NotakaseCore
import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: DesktopModel
    @ObservedObject var store: NotakaseStore
    @FocusState private var searchFocused: Bool
    @FocusState private var createFocused: Bool

    private var theme: Theme { store.theme }

    // MARK: tree model
    private enum Row: Identifiable {
        case folder(
            id: String, name: String, glyph: String, path: String,
            depth: Int, open: Bool, count: Int)
        case note(note: Note, depth: Int, active: Bool)
        case input(kind: DesktopModel.Creating.Kind, depth: Int, placeholder: String)

        var id: String {
            switch self {
            case .folder(let id, _, _, _, _, _, _): return "f:" + id
            case .note(let n, _, _): return "n:" + n.id
            case .input(_, let d, _): return "i:\(d)"
            }
        }
    }

    private func buildRows() -> [Row] {
        let q = model.search.lowercased().trimmingCharacters(in: .whitespaces)
        func match(_ n: Note) -> Bool {
            q.isEmpty || (n.title + " " + n.body).lowercased().contains(q)
        }
        let visible = q.isEmpty ? store.notes : store.notes.filter(match)
        let cr = model.creating
        var rows: [Row] = []

        // Loose notes at the top level (no folder) come first so they're
        // easy to find and file away later.
        for n in visible where n.dir.isEmpty {
            rows.append(.note(note: n, depth: 0, active: n.id == model.current.id))
        }

        // Top-level folders: the explicit order first, then any surfaced by
        // notes that aren't already listed.
        var tops = store.folderOrder
        for t in visible.compactMap({ $0.dir.first }) where !tops.contains(t) {
            tops.append(t)
        }
        for top in tops {
            appendFolder(path: [top], visible: visible, depth: 0, q: q, cr: cr, into: &rows)
        }
        if cr?.kind == .folder {
            rows.append(.input(kind: .folder, depth: 0, placeholder: "folder-name…"))
        }
        return rows
    }

    /// Recursively emit a folder and its contents at arbitrary depth.
    private func appendFolder(
        path: [String], visible: [Note], depth: Int, q: String,
        cr: DesktopModel.Creating?, into rows: inout [Row]
    ) {
        // Notes at or below this folder path.
        let below = visible.filter {
            $0.dir.count >= path.count && Array($0.dir.prefix(path.count)) == path
        }
        let creatingHere = cr?.kind == .note && cr?.parent == path
        if !q.isEmpty && below.isEmpty && !creatingHere { return }

        let key = path.joined(separator: "/")
        let open = q.isEmpty ? !model.collapsed.contains(key) : true
        let glyph = depth == 0 ? (SeedData.folderGlyph[path[0]] ?? "▤") : "▤"
        rows.append(
            .folder(
                id: key, name: path.last ?? key, glyph: glyph, path: key,
                depth: depth, open: open, count: below.count))
        guard open else { return }

        if creatingHere {
            rows.append(.input(kind: .note, depth: depth + 1, placeholder: "Untitled note…"))
        }
        // Direct notes first, then child folders (alphabetical) — the order the
        // two-level tree used, now applied at every level.
        for n in below where n.dir == path {
            rows.append(.note(note: n, depth: depth + 1, active: n.id == model.current.id))
        }
        var childNames: [String] = []
        for n in below where n.dir.count > path.count {
            let child = n.dir[path.count]
            if !childNames.contains(child) { childNames.append(child) }
        }
        for child in childNames.sorted() {
            appendFolder(
                path: path + [child], visible: visible, depth: depth + 1,
                q: q, cr: cr, into: &rows)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBox
            libraryHeader
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(buildRows()) { row in
                        rowView(row)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 14)
            }
        }
        .frame(maxHeight: .infinity)
        .background(theme.sidebarColor)
        .overlay(alignment: .trailing) {
            Rectangle().fill(theme.borderColor).frame(width: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.accentColor)
                    .frame(width: 20, height: 20)
                Circle()
                    .fill(theme.sidebarColor)
                    .frame(width: 6, height: 6)
                    .padding([.trailing, .bottom], 3)
            }
            Text("Notakase")
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.fgColor)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16).padding(.bottom, 12)
    }

    private var searchBox: some View {
        HStack(spacing: 8) {
            Text("⌕").foregroundStyle(theme.faintColor).font(.system(size: 12))
            TextField("Search", text: $model.search)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.fgColor)
                .focused($searchFocused)
            Text("⌘K")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(theme.faintColor)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(theme.borderColor, lineWidth: 1))
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(theme.elevatedColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(theme.borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12).padding(.bottom, 12)
    }

    private var libraryHeader: some View {
        HStack(spacing: 6) {
            Text("LIBRARY")
                .font(.system(size: 9.5))
                .tracking(1.3)
                .foregroundStyle(theme.faintColor)
            Spacer()
            addButton(glyph: "¶") { model.startNote() }
            addButton(glyph: "▤") { model.startFolder() }
        }
        .padding(.horizontal, 14).padding(.bottom, 8).padding(.top, 2)
    }

    private func addButton(glyph: String, action: @escaping () -> Void) -> some View {
        HoverButton(action: action) { hovering in
            HStack(spacing: 0) {
                Text(glyph).font(.system(size: 11, design: .monospaced))
                Text("+").font(.system(size: 13, weight: .light, design: .monospaced))
                    .padding(.leading, -1)
            }
            .foregroundStyle(hovering ? theme.fgColor : theme.fgMutedColor)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        hovering ? theme.accentColor : theme.borderColor,
                        lineWidth: 1))
            .background(hovering ? theme.elevatedColor : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    /// Right-click "Move to" menu for a note row. `s` opens the same set as a
    /// keyboard-driven overlay.
    @ViewBuilder
    private func moveMenu(for note: Note) -> some View {
        Text("Move to")
        if !note.dir.isEmpty {
            Button("Top level") { store.moveNote(id: note.id, to: []) }
        }
        ForEach(store.folderPaths.filter { $0 != note.dir }, id: \.self) { dir in
            Button(dir.joined(separator: " / ")) { store.moveNote(id: note.id, to: dir) }
        }
    }

    @ViewBuilder
    private func rowView(_ row: Row) -> some View {
        switch row {
        case .folder(_, let name, let glyph, let path, let depth, let open, let count):
            HoverButton(action: { model.toggleFolder(path) }) { hovering in
                HStack(spacing: 7) {
                    Spacer().frame(width: CGFloat(6 + depth * 15))
                    Text(open ? "▾" : "▸")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.faintColor)
                        .frame(width: 11)
                    Text(glyph)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.accentColor)
                        .opacity(0.85)
                    Text(name)
                        .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.fgColor)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(theme.faintColor)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(hovering ? theme.elevatedColor.opacity(0.55) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }

        case .note(let n, let depth, let active):
            HoverButton(action: { model.openNote(n.id) }) { hovering in
                HStack(spacing: 7) {
                    Spacer().frame(width: CGFloat(12 + depth * 15))
                    Text(n.title + ".md")
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(active || hovering ? theme.fgColor : theme.fgMutedColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(
                    active
                        ? theme.elevatedColor
                        : (hovering ? theme.elevatedColor.opacity(0.55) : .clear)
                )
                .overlay(alignment: .leading) {
                    if active {
                        Rectangle().fill(theme.accentColor).frame(width: 2)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .contextMenu { moveMenu(for: n) }

        case .input(let kind, let depth, let placeholder):
            HStack(spacing: 7) {
                Spacer().frame(
                    width: CGFloat((kind == .folder ? 6 : 12) + depth * 15))
                Text(kind == .folder ? "▤" : "¶")
                    .font(.system(size: 12)).foregroundStyle(theme.accentColor)
                TextField(placeholder, text: $model.createValue)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(theme.fgColor)
                    .focused($createFocused)
                    .onSubmit { model.commitCreate() }
                    .onExitCommand { model.cancelCreate() }
                    .onAppear { createFocused = true }
                Text("↵").font(.system(size: 9.5)).foregroundStyle(theme.faintColor)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(theme.accentColor.opacity(0.12))
            .overlay(alignment: .leading) {
                Rectangle().fill(theme.accentColor).frame(width: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
    }
}
