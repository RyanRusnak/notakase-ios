import NotakaseCore
import SwiftUI

/// A destination in the library's navigation stack: either drilling into a
/// folder (identified by its full path components) or opening a note.
enum LibraryRoute: Hashable {
    case folder([String])
    case note(String)
}

struct LibraryView: View {
    @EnvironmentObject var store: NotakaseStore
    @EnvironmentObject var syncFolder: SyncFolder
    @EnvironmentObject var todokase: TodokaseTasks
    @State private var search = ""
    @State private var path: [LibraryRoute] = []
    @State private var showSettings = false

    private var theme: Theme { store.theme }

    private var searching: Bool {
        !search.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func match(_ n: Note) -> Bool {
        let q = search.lowercased().trimmingCharacters(in: .whitespaces)
        return q.isEmpty || (n.title + " " + n.body).lowercased().contains(q)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottomTrailing) {
                background
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        if searching {
                            searchResults
                        } else {
                            // Root of the tree: top-level folders (+ any loose
                            // root notes), drilled into from here.
                            FolderContents(dir: [], path: $path)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
                .refreshable {
                    // Pull down to re-read the folder + task store on demand.
                    store.reloadFromDisk()
                    todokase.reload()
                }
                // New notes from the index land at the top level; move them
                // into a folder later via long-press.
                floatingAdd(dir: [])
            }
            .navigationBarHidden(true)
            .navigationDestination(for: LibraryRoute.self) { route in
                switch route {
                case .folder(let dir): FolderScreen(dir: dir, path: $path)
                case .note(let id): ReaderView(noteID: id)
                }
            }
        }
        .tint(theme.accentColor)
        .sheet(isPresented: $showSettings) {
            SettingsSheet(onClose: { showSettings = false })
                .environmentObject(store)
                .environmentObject(syncFolder)
                .environmentObject(todokase)
                .preferredColorScheme(theme.isDark ? .dark : .light)
        }
        .onChange(of: store.pendingOpenNoteID) { _, id in
            if let id, store.note(id: id) != nil {
                path = [.note(id)]
                store.pendingOpenNoteID = nil
            }
        }
        .onChange(of: syncFolder.folderURL) { _, url in
            store.applySyncFolder(url)
        }
        .task {
            store.applySyncFolder(syncFolder.folderURL)
            #if DEBUG
            if let p = ProcessInfo.processInfo.environment["NK_FOLDER"] {
                syncFolder.setFolder(URL(fileURLWithPath: p, isDirectory: true))
            }
            if let p = ProcessInfo.processInfo.environment["NK_TASKS"] {
                todokase.setFile(URL(fileURLWithPath: p))
            }
            #endif
            #if DEBUG
            // Dev hooks: `SIMCTL_CHILD_NK_THEME=<id>` preselects a theme and
            // `SIMCTL_CHILD_NK_OPEN="<title>"` opens straight into a note.
            if let raw = ProcessInfo.processInfo.environment["NK_THEME"],
                let t = ThemeName(rawValue: raw)
            {
                store.setTheme(t)
            }
            if let title = ProcessInfo.processInfo.environment["NK_OPEN"],
                let n = store.note(title: title)
            {
                path = [.note(n.id)]
            }
            // `SIMCTL_CHILD_NK_OPEN_FOLDER="A/B/C"` drills straight into a folder.
            if let raw = ProcessInfo.processInfo.environment["NK_OPEN_FOLDER"] {
                path = [.folder(raw.split(separator: "/").map(String.init))]
            }
            if ProcessInfo.processInfo.environment["NK_SETTINGS"] != nil {
                showSettings = true
            }
            #endif
        }
    }

    private var background: some View {
        theme.bgColor.ignoresSafeArea()
    }

    /// `~/notakase_sync`-style path shown in the header (like todokase mobile).
    private var headerPath: String {
        syncFolder.isSet ? "~/\(syncFolder.folderName ?? "notes")" : "notakase"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                Text(headerPath)
                    .font(Typo.mono(17, weight: .medium))
                    .foregroundStyle(theme.fgColor)
                    .lineLimit(1)
                    .truncationMode(.head)
                Text("· \(store.notes.count)")
                    .font(Typo.mono(13))
                    .foregroundStyle(theme.faintColor)
                Spacer()
                themeMenu
                gearButton
            }
            .padding(.top, 8)

            HStack(spacing: 9) {
                Text("⌕").foregroundStyle(theme.faintColor).font(.system(size: 14))
                TextField("Search notes", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.fgColor)
            }
            .padding(.horizontal, 13).padding(.vertical, 10)
            .background(theme.elevatedColor)
            .overlay(
                RoundedRectangle(cornerRadius: 11).stroke(theme.borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .padding(.top, 16)
        }
        .padding(.bottom, 8)
    }

    /// Search spans every folder — results are flat, each labelled with its
    /// full path so you can tell nested notes apart.
    private var searchResults: some View {
        let hits = store.notes.filter(match)
        return VStack(alignment: .leading, spacing: 12) {
            if hits.isEmpty {
                Text("No matches")
                    .font(Typo.mono(13))
                    .foregroundStyle(theme.faintColor)
                    .padding(.top, 24)
            }
            ForEach(Array(hits.enumerated()), id: \.element.id) { idx, note in
                NavigationLink(value: LibraryRoute.note(note.id)) {
                    NoteCard(
                        note: note, indexInGroup: idx,
                        pathLabel: note.folderPath, theme: theme)
                }
                .buttonStyle(.plain)
                .contextMenu { NoteMoveMenu(note: note) }
            }
        }
        .padding(.top, 18)
    }

    private var themeMenu: some View {
        Menu {
            ForEach(Theme.order) { id in
                Button {
                    store.setTheme(id)
                } label: {
                    if id == theme.name {
                        Label(Theme.named(id).label, systemImage: "checkmark")
                    } else {
                        Text(Theme.named(id).label)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(theme.accentColor).frame(width: 9, height: 9)
                Text(theme.short)
                    .font(Typo.mono(11))
                    .foregroundStyle(theme.fgMutedColor)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .overlay(
                RoundedRectangle(cornerRadius: 8).stroke(theme.borderColor, lineWidth: 1)
            )
        }
    }

    private var gearButton: some View {
        Button { showSettings = true } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 14))
                .foregroundStyle(theme.fgMutedColor)
                .frame(width: 32, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(theme.borderColor, lineWidth: 1)
                )
        }
    }

    private func floatingAdd(dir: [String]) -> some View {
        Button {
            let n = store.addNote(dir: dir, title: "Untitled")
            path.append(.note(n.id))
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(theme.bgColor)
                .frame(width: 56, height: 56)
                .background(theme.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: theme.accentColor.opacity(0.45), radius: 13, y: 10)
        }
        .padding(.trailing, 22).padding(.bottom, 40)
    }
}

/// The immediate contents of one folder path: its child folders (which drill
/// deeper) followed by the notes filed directly in it. Reused for the root
/// (`dir == []`) and every pushed folder screen, so nesting is unbounded.
struct FolderContents: View {
    @EnvironmentObject var store: NotakaseStore
    let dir: [String]
    @Binding var path: [LibraryRoute]

    private var theme: Theme { store.theme }

    var body: some View {
        let all = store.notes
        let below = all.filter {
            $0.dir.count >= dir.count && Array($0.dir.prefix(dir.count)) == dir
        }
        let children = childFolderNames(below)
        let directNotes = below.filter { $0.dir == dir }

        VStack(alignment: .leading, spacing: 12) {
            ForEach(children, id: \.self) { name in
                let childDir = dir + [name]
                NavigationLink(value: LibraryRoute.folder(childDir)) {
                    FolderRow(
                        dir: childDir,
                        count: countBelow(childDir, in: all),
                        theme: theme)
                }
                .buttonStyle(.plain)
            }
            ForEach(Array(directNotes.enumerated()), id: \.element.id) { idx, note in
                NavigationLink(value: LibraryRoute.note(note.id)) {
                    NoteCard(note: note, indexInGroup: idx, theme: theme)
                }
                .buttonStyle(.plain)
                .contextMenu { NoteMoveMenu(note: note) }
            }
            if children.isEmpty && directNotes.isEmpty {
                Text("Empty folder")
                    .font(Typo.mono(13))
                    .foregroundStyle(theme.faintColor)
                    .padding(.top, 24)
            }
        }
    }

    /// Immediate child folder names under `dir`. At the root they follow the
    /// store's folder order; deeper levels are alphabetical.
    private func childFolderNames(_ below: [Note]) -> [String] {
        var names: [String] = []
        for n in below where n.dir.count > dir.count {
            let c = n.dir[dir.count]
            if !names.contains(c) { names.append(c) }
        }
        if dir.isEmpty {
            var ordered = store.folderOrder.filter { names.contains($0) }
            for n in names where !ordered.contains(n) { ordered.append(n) }
            return ordered
        }
        return names.sorted()
    }

    private func countBelow(_ prefix: [String], in notes: [Note]) -> Int {
        notes.filter {
            $0.dir.count >= prefix.count && Array($0.dir.prefix(prefix.count)) == prefix
        }.count
    }
}

/// A pushed screen showing one folder's contents, with a floating add that
/// files new notes into *this* folder.
struct FolderScreen: View {
    @EnvironmentObject var store: NotakaseStore
    let dir: [String]
    @Binding var path: [LibraryRoute]

    private var theme: Theme { store.theme }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            theme.bgColor.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if dir.count > 1 {
                        Text(dir.joined(separator: " / "))
                            .font(Typo.mono(11))
                            .foregroundStyle(theme.faintColor)
                            .lineLimit(1)
                            .truncationMode(.head)
                            .padding(.bottom, 6)
                    }
                    FolderContents(dir: dir, path: $path)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            Button {
                let n = store.addNote(dir: dir, title: "Untitled")
                path.append(.note(n.id))
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(theme.bgColor)
                    .frame(width: 56, height: 56)
                    .background(theme.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: theme.accentColor.opacity(0.45), radius: 13, y: 10)
            }
            .padding(.trailing, 22).padding(.bottom, 40)
        }
        .navigationTitle(dir.last ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.bgColor, for: .navigationBar)
        .tint(theme.accentColor)
    }
}

/// Long-press (iOS) menu to file a note into a folder or the top level.
struct NoteMoveMenu: View {
    @EnvironmentObject var store: NotakaseStore
    let note: Note

    var body: some View {
        Section("Move to") {
            if !note.dir.isEmpty {
                Button {
                    store.moveNote(id: note.id, to: [])
                } label: { Label("Top level", systemImage: "tray") }
            }
            ForEach(store.folderPaths.filter { $0 != note.dir }, id: \.self) { dir in
                Button {
                    store.moveNote(id: note.id, to: dir)
                } label: {
                    Label(dir.joined(separator: " / "), systemImage: "folder")
                }
            }
        }
    }
}

struct FolderRow: View {
    let dir: [String]
    let count: Int
    let theme: Theme

    private var glyph: String {
        dir.count == 1 ? (SeedData.folderGlyph[dir[0]] ?? "▤") : "▤"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(glyph)
                .font(.system(size: 16))
                .foregroundStyle(theme.accentColor)
                .opacity(0.85)
            Text(dir.last ?? "")
                .font(Typo.mono(16, weight: .medium))
                .foregroundStyle(theme.fgColor)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(count)")
                .font(Typo.mono(12))
                .foregroundStyle(theme.faintColor)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.faintColor)
        }
        .padding(.horizontal, 14).padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.elevatedColor)
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(theme.borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct NoteCard: View {
    let note: Note
    let indexInGroup: Int
    /// Optional full-path caption, shown in flat (search) listings.
    var pathLabel: String? = nil
    let theme: Theme

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            RoundedRectangle(cornerRadius: 3)
                .fill(iOSHelpers.barColor(for: note, indexInGroup: indexInGroup, theme: theme))
                .frame(width: 3)
                .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 4) {
                if let pathLabel, !pathLabel.isEmpty {
                    Text(pathLabel)
                        .font(Typo.mono(10))
                        .foregroundStyle(theme.faintColor)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                Text(note.title)
                    .font(Typo.mono(17, weight: .semibold))
                    .foregroundStyle(theme.fgColor)
                    .lineLimit(1)
                Text(iOSHelpers.snippet(note))
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.fgMutedColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 9) {
                    Text(note.updated)
                        .font(Typo.mono(10.5))
                        .foregroundStyle(theme.faintColor)
                    if let tag = iOSHelpers.tag(note) {
                        Text(tag.uppercased())
                            .font(.system(size: 9.5)).tracking(0.6)
                            .foregroundStyle(theme.accentColor)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(theme.accentColor.opacity(0.4), lineWidth: 1))
                    }
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.elevatedColor)
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(theme.borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
