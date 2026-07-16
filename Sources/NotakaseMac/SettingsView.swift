import NotakaseCore
import SwiftUI
import UniformTypeIdentifiers

/// The macOS Settings window (⌘,). For now it hosts the sync-folder picker.
struct SettingsView: View {
    @ObservedObject var store: NotakaseStore
    @ObservedObject var syncFolder: SyncFolder
    @ObservedObject var todokase: TodokaseTasks
    @State private var showPicker = false
    @State private var showTasksPicker = false

    private var theme: Theme { store.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SYNC FOLDER")
                .font(Typo.mono(10))
                .tracking(1.3)
                .foregroundStyle(theme.faintColor)

            Text(
                "Point Notakase at a folder of markdown. Your notes read and write here — pick an iCloud Drive, Dropbox or Syncthing folder to sync across devices."
            )
            .font(Typo.mono(12.5))
            .foregroundStyle(theme.fgMutedColor)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)

            folderCard

            HStack(spacing: 10) {
                Button(action: { showPicker = true }) {
                    Text(syncFolder.isSet ? "Change Folder…" : "Choose Folder…")
                        .font(Typo.mono(12.5, weight: .semibold))
                        .foregroundStyle(theme.bgColor)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(theme.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                if syncFolder.isSet {
                    Button(action: { syncFolder.clearFolder() }) {
                        Text("Clear")
                            .font(Typo.mono(12.5))
                            .foregroundStyle(theme.fgMutedColor)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(theme.borderColor, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            // Each picker is attached to its own subview — two `.fileImporter`s
            // on the *same* view silently conflict and one stops working.
            .fileImporter(
                isPresented: $showPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    syncFolder.setFolder(url)
                }
            }

            todokaseSection

            Spacer()
        }
        .padding(24)
        .frame(width: 540, height: 470)
        .background(theme.bgColor)
        .foregroundStyle(theme.fgColor)
        .preferredColorScheme(theme.isDark ? .dark : .light)
    }

    private var todokaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().overlay(theme.borderColor).padding(.vertical, 4)

            Text("TODOKASE TASKS")
                .font(Typo.mono(10))
                .tracking(1.3)
                .foregroundStyle(theme.faintColor)

            Text(
                "Point at todokase's tasks.automerge to embed live task lists in a note with a ```todokase fenced block."
            )
            .font(Typo.mono(12.5))
            .foregroundStyle(theme.fgMutedColor)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: { showTasksPicker = true }) {
                    Text(todokase.isSet ? "Change File…" : "Choose tasks.automerge…")
                        .font(Typo.mono(12.5, weight: .semibold))
                        .foregroundStyle(theme.bgColor)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(theme.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                if todokase.isSet {
                    Button(action: { todokase.clearFile() }) {
                        Text("Clear")
                            .font(Typo.mono(12.5))
                            .foregroundStyle(theme.fgMutedColor)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(theme.borderColor, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            if todokase.isSet {
                Text(todokase.displayPath)
                    .font(Typo.mono(11))
                    .foregroundStyle(theme.faintColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
        .fileImporter(
            isPresented: $showTasksPicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                todokase.setFile(url)
            }
        }
    }

    private var folderCard: some View {
        HStack(spacing: 12) {
            Image(systemName: syncFolder.isSet ? "folder.fill" : "folder.badge.questionmark")
                .font(.system(size: 20))
                .foregroundStyle(syncFolder.isSet ? theme.accentColor : theme.faintColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(syncFolder.folderName ?? "No folder selected")
                    .font(Typo.mono(14, weight: .semibold))
                    .foregroundStyle(theme.fgColor)
                HStack(spacing: 7) {
                    if syncFolder.isSet {
                        SyncHealthDot(store: store, theme: theme)
                    }
                    Text(syncFolder.isSet ? syncFolder.displayPath : "Choose a folder to begin")
                        .font(Typo.mono(11.5))
                        .foregroundStyle(theme.faintColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.elevatedColor)
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(theme.borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
