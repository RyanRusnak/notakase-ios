import NotakaseCore
import SwiftUI
import UniformTypeIdentifiers

/// iOS settings sheet, reached via the gear in the Library header. Hosts the
/// sync-folder picker (and the theme list, since it's a natural home).
struct SettingsSheet: View {
    @EnvironmentObject var store: NotakaseStore
    @EnvironmentObject var syncFolder: SyncFolder
    @EnvironmentObject var todokase: TodokaseTasks
    let onClose: () -> Void

    @State private var showPicker = false
    @State private var showTasksPicker = false

    private var theme: Theme { store.theme }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    syncSection
                    todokaseSection
                    appearanceSection
                }
                .padding(20)
            }
            .background(theme.bgColor.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onClose)
                        .foregroundStyle(theme.accentColor)
                }
            }
        }
        .tint(theme.accentColor)
    }

    private var todokaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("TODOKASE TASKS")
            Text(
                "Point at todokase's tasks.automerge to embed live task lists in a note with a ```todokase fenced block."
            )
            .font(.system(size: 13))
            .foregroundStyle(theme.fgMutedColor)
            .fixedSize(horizontal: false, vertical: true)

            if todokase.isSet {
                Text(todokase.displayPath)
                    .font(Typo.mono(12))
                    .foregroundStyle(theme.faintColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack(spacing: 10) {
                Button(action: { showTasksPicker = true }) {
                    Text(todokase.isSet ? "Change File…" : "Choose tasks.automerge…")
                        .font(Typo.mono(14, weight: .semibold))
                        .foregroundStyle(theme.bgColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(theme.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                if todokase.isSet {
                    Button(action: { todokase.clearFile() }) {
                        Text("Clear")
                            .font(Typo.mono(14))
                            .foregroundStyle(theme.fgMutedColor)
                            .padding(.horizontal, 18).padding(.vertical, 11)
                            .overlay(
                                RoundedRectangle(cornerRadius: 11)
                                    .stroke(theme.borderColor, lineWidth: 1))
                    }
                }
            }
        }
        // Attached here, not on the shared body — two `.fileImporter`s on one
        // view conflict and one stops opening.
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

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SYNC FOLDER")
            Text(
                "Point Notakase at a folder of markdown. Pick an iCloud Drive, Dropbox or Syncthing folder to keep notes in sync across devices."
            )
            .font(.system(size: 13))
            .foregroundStyle(theme.fgMutedColor)
            .fixedSize(horizontal: false, vertical: true)

            folderCard

            HStack(spacing: 10) {
                Button(action: { showPicker = true }) {
                    Text(syncFolder.isSet ? "Change Folder…" : "Choose Folder…")
                        .font(Typo.mono(14, weight: .semibold))
                        .foregroundStyle(theme.bgColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(theme.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                if syncFolder.isSet {
                    Button(action: { syncFolder.clearFolder() }) {
                        Text("Clear")
                            .font(Typo.mono(14))
                            .foregroundStyle(theme.fgMutedColor)
                            .padding(.horizontal, 18).padding(.vertical, 11)
                            .overlay(
                                RoundedRectangle(cornerRadius: 11)
                                    .stroke(theme.borderColor, lineWidth: 1))
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                syncFolder.setFolder(url)
            }
        }
    }

    private var folderCard: some View {
        HStack(spacing: 12) {
            Image(systemName: syncFolder.isSet ? "folder.fill" : "folder.badge.questionmark")
                .font(.system(size: 22))
                .foregroundStyle(syncFolder.isSet ? theme.accentColor : theme.faintColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(syncFolder.folderName ?? "No folder selected")
                    .font(Typo.mono(15, weight: .semibold))
                    .foregroundStyle(theme.fgColor)
                HStack(spacing: 7) {
                    if syncFolder.isSet {
                        SyncHealthDot(store: store, theme: theme)
                    }
                    Text(syncFolder.isSet ? syncFolder.displayPath : "Choose a folder to begin")
                        .font(Typo.mono(12))
                        .foregroundStyle(theme.faintColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.elevatedColor)
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(theme.borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("THEME")
            VStack(spacing: 0) {
                ForEach(Theme.order) { id in
                    let t = Theme.named(id)
                    Button(action: { store.setTheme(id) }) {
                        HStack(spacing: 12) {
                            Circle().fill(t.accentColor).frame(width: 12, height: 12)
                            Text(t.label)
                                .font(Typo.mono(14))
                                .foregroundStyle(theme.fgColor)
                            Spacer()
                            if id == theme.name {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(theme.accentColor)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(
                            id == theme.name
                                ? theme.accentColor.opacity(0.14) : Color.clear)
                    }
                }
            }
            .background(theme.elevatedColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(theme.borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func sectionHeader(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 11)).tracking(1.3)
            .foregroundStyle(theme.faintColor)
    }
}
