import NotakaseCore
import SwiftUI

struct ReaderView: View {
    @EnvironmentObject var store: NotakaseStore
    @Environment(\.dismiss) private var dismiss

    let noteID: String
    @State private var currentID: String
    @State private var editing = false
    @State private var draft = ""

    init(noteID: String) {
        self.noteID = noteID
        _currentID = State(initialValue: noteID)
    }

    private var theme: Theme { store.theme }
    private var note: Note { store.note(id: currentID) ?? store.notes[0] }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            content
        }
        .background(theme.bgColor.ignoresSafeArea())
        .navigationBarHidden(true)
        // The hidden nav bar disables the system swipe-back, so recognise a
        // left-edge rightward pan and pop one level (back to where we came from).
        .simultaneousGesture(
            DragGesture(minimumDistance: 15, coordinateSpace: .global)
                .onEnded { v in
                    guard v.startLocation.x < 20,
                        v.translation.width > 90,
                        abs(v.translation.height) < 60
                    else { return }
                    commitDraftIfNeeded()
                    dismiss()
                }
        )
        .onWikiLink { title in
            if let n = store.note(title: title) {
                commitDraftIfNeeded()
                currentID = n.id
                editing = false
            }
        }
        .onAppear { draft = note.body }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                commitDraftIfNeeded()
                dismiss()
            } label: {
                Text("‹")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.fgMutedColor)
                    .frame(width: 34, height: 34)
                    .background(theme.elevatedColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(theme.borderColor, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            VStack(spacing: 2) {
                Text(note.folderPath.isEmpty ? note.folder : note.folderPath)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.fgMutedColor)
                    .lineLimit(1)
                    .truncationMode(.head)
                Text(note.fileName)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.faintColor)
            }
            .frame(maxWidth: .infinity)
            // Mode indicator + editor toggle, moved up from the old bottom bar.
            Text(editing ? "WRITE" : "READ")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(theme.bgColor)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(editing ? theme.accent2Color : theme.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            Button {
                if editing { commitDraftIfNeeded() }
                editing.toggle()
            } label: {
                Image(systemName: editing ? "eye" : "pencil")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.bgColor)
                    .frame(width: 34, height: 34)
                    .background(theme.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.borderColor).frame(height: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        if editing {
            TextEditor(text: $draft)
                .font(.system(size: 16, design: .monospaced))
                .foregroundStyle(theme.fgColor)
                .scrollContentBackground(.hidden)
                .background(theme.bgColor)
                .tint(theme.accentColor)
                .padding(.horizontal, 18).padding(.top, 12)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(displayTitle)
                        .font(.system(size: 29, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.fgColor)
                        .padding(.bottom, 6)
                    Text("edited \(note.updated) · \(note.wordCount) words")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.faintColor)
                        .padding(.bottom, 22)
                    ForEach(Array(bodyBlocks.enumerated()), id: \.offset) { i, block in
                        // skip the leading H1 (shown as the large title)
                        if !(i == 0 && isH1(block)) {
                            BlockView(block: block, theme: theme, baseSize: 17)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 22).padding(.vertical, 20)
            }
        }
    }

    // MARK: helpers
    private var bodyBlocks: [Block] { Markdown.parse(note.body) }

    private func isH1(_ block: Block) -> Bool {
        if case .heading(let level, _, _) = block { return level == 1 }
        return false
    }

    private var displayTitle: String {
        if let first = bodyBlocks.first, case .heading(1, let text, _) = first {
            return text
        }
        return note.title
    }

    private func commitDraftIfNeeded() {
        if editing && draft != note.body {
            store.updateBody(id: currentID, draft)
        }
    }
}
