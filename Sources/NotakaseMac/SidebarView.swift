import NotakaseCore
import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: DesktopModel
    @ObservedObject var store: NotakaseStore
    @FocusState private var searchFocused: Bool
    @FocusState private var createFocused: Bool

    private var theme: Theme { store.theme }

    /// The id of the row currently under the keyboard selection cursor.
    private var selectedID: String? {
        let rows = model.selectableRows
        guard rows.indices.contains(model.treeSel) else { return nil }
        return rows[model.treeSel].id
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBox
            libraryHeader
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.visibleRows()) { row in
                            rowView(row, selected: row.id == selectedID)
                                .id(row.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 14)
                }
                .onChange(of: model.treeSel) {
                    if let id = selectedID { withAnimation { proxy.scrollTo(id) } }
                }
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
                .font(Typo.mono(18, weight: .semibold))
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
                .font(Typo.mono(12))
                .foregroundStyle(theme.fgColor)
                .focused($searchFocused)
                .onChange(of: model.focusSearch) {
                    if model.focusSearch {
                        searchFocused = true
                        model.focusSearch = false
                    }
                }
            Text("⌘K")
                .font(Typo.mono(10))
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
            addButton(glyph: "¶") { searchFocused = false; model.startNote() }
            addButton(glyph: "▤") { searchFocused = false; model.startFolder() }
        }
        .padding(.horizontal, 14).padding(.bottom, 8).padding(.top, 2)
    }

    private func addButton(glyph: String, action: @escaping () -> Void) -> some View {
        HoverButton(action: action) { hovering in
            HStack(spacing: 0) {
                Text(glyph).font(Typo.mono(11))
                Text("+").font(Typo.mono(13, weight: .light))
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

    private func rowBackground(selected: Bool, hovering: Bool, active: Bool) -> Color {
        if selected { return theme.accentColor.opacity(0.16) }
        if active { return theme.elevatedColor }
        if hovering { return theme.elevatedColor.opacity(0.55) }
        return .clear
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
    private func rowView(_ row: DesktopModel.SidebarRow, selected: Bool) -> some View {
        switch row {
        case .folder(let path, let glyph, let depth, let open, let count):
            let key = path.joined(separator: "/")
            HoverButton(action: {
                searchFocused = false
                model.selectRow(row)
                model.toggleFolder(key)
            }) { hovering in
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
                    Text(path.last ?? key)
                        .font(Typo.mono(12.5, weight: .medium))
                        .foregroundStyle(theme.fgColor)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if count > 0 {
                        Text("\(count)")
                            .font(Typo.mono(10))
                            .foregroundStyle(theme.faintColor)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(rowBackground(selected: selected, hovering: hovering, active: false))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }

        case .note(let n, let depth):
            let active = n.id == model.current.id
            HoverButton(action: {
                searchFocused = false
                model.selectRow(row)
                model.openNote(n.id)
            }) { hovering in
                HStack(spacing: 7) {
                    Spacer().frame(width: CGFloat(12 + depth * 15))
                    Text(n.title + ".md")
                        .font(Typo.mono(12.5))
                        .foregroundStyle(
                            selected || active || hovering ? theme.fgColor : theme.fgMutedColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(rowBackground(selected: selected, hovering: hovering, active: active))
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
                    .font(Typo.mono(12.5))
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
