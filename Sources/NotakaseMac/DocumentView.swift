import NotakaseCore
import SwiftUI

struct DocumentView: View {
    @ObservedObject var model: DesktopModel
    let theme: Theme
    @FocusState private var editorFocused: Bool

    var body: some View {
        if model.view == .publish {
            publishView
                .frame(maxWidth: 760)
        } else if model.view == .edit {
            editor
                .frame(maxWidth: 680)
        } else {
            reader
                .frame(maxWidth: 680)
        }
    }

    private func docHeader(_ n: Note) -> some View {
        HStack(spacing: 10) {
            Text((n.dir + [n.fileName]).joined(separator: " / "))
            Text("·")
            Text(model.view == .edit ? "editing" : "edited " + n.updated)
        }
        .font(Typo.mono(11.5))
        .foregroundStyle(theme.faintColor)
        .padding(.bottom, 26)
    }

    // MARK: read (rendered preview)
    private var reader: some View {
        let n = model.current
        let blocks = model.blocks
        return VStack(alignment: .leading, spacing: 0) {
            docHeader(n)
            ForEach(Array(blocks.enumerated()), id: \.offset) { i, block in
                BlockView(block: block, theme: theme)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("block-\(i)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: write (full-note markdown editor)
    private var editor: some View {
        let n = model.current
        return VStack(alignment: .leading, spacing: 0) {
            docHeader(n)
            TextEditor(text: $model.draft)
                .font(Typo.mono(15))
                .foregroundStyle(theme.fgColor)
                .tint(theme.accentColor)
                .scrollContentBackground(.hidden)
                .background(theme.bgColor)
                .frame(minHeight: 460, alignment: .topLeading)
                .focused($editorFocused)
                // Defer to the next runloop so focus lands *after* the previous
                // first responder (the create-name field, or the reader) has
                // resigned — otherwise the cursor never enters the editor.
                .onAppear {
                    DispatchQueue.main.async { editorFocused = true }
                }
                .onChange(of: model.openId) {
                    DispatchQueue.main.async { editorFocused = true }
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: publish
    private var publishView: some View {
        let n = model.current
        let blocks = model.blocks
        let pages = model.store.notes.filter { $0.folder == n.folder }
        let isSite = n.folder == "notakase.dev"
        let url =
            isSite
            ? "notakase.dev/" + (n.slug ?? "index")
            : n.folder.lowercased() + "/"
                + n.fileName.replacingOccurrences(of: ".md", with: "")

        return VStack(alignment: .leading, spacing: 0) {
            // browser chrome
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    ForEach(0..<3) { _ in
                        Circle().fill(theme.borderColor).frame(width: 10, height: 10)
                    }
                }
                Text(url)
                    .font(Typo.mono(12))
                    .foregroundStyle(theme.faintColor)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(theme.elevatedColor)
            .overlay(
                RoundedRectangle(cornerRadius: 9).stroke(theme.borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .padding(.bottom, 22)

            // nav
            HStack(spacing: 18) {
                ForEach(pages) { p in
                    let active = p.id == n.id
                    Button(action: { model.openNote(p.id) }) {
                        Text(p.title)
                            .font(Typo.mono(13))
                            .foregroundStyle(active ? theme.accentColor : theme.fgMutedColor)
                            .padding(.bottom, 4)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(active ? theme.accentColor : .clear)
                                    .frame(height: 2)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 18)
            .overlay(alignment: .bottom) {
                Rectangle().fill(theme.borderColor).frame(height: 1)
            }
            .padding(.bottom, 30)

            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                BlockView(block: block, theme: theme)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // footer
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.accentColor).frame(width: 7, height: 7)
                Text(
                    isSite
                        ? "Built with Notakase · static export"
                        : "Preview — publish this folder to make it a site"
                )
                .font(Typo.mono(11))
                .foregroundStyle(theme.faintColor)
            }
            .padding(.top, 18)
            .overlay(alignment: .top) {
                Rectangle().fill(theme.borderColor).frame(height: 1)
            }
            .padding(.top, 30)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
