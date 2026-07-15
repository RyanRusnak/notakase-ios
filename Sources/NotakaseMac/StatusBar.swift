import NotakaseCore
import SwiftUI

struct StatusBar: View {
    @ObservedObject var model: DesktopModel
    let theme: Theme
    @EnvironmentObject var syncFolder: SyncFolder
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let n = model.current
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(ViewMode.allCases, id: \.self) { v in
                    let active = model.view == v
                    Button(action: { model.setView(v) }) {
                        Text(v.label)
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(active ? theme.bgColor : theme.faintColor)
                            .padding(.horizontal, 13)
                            .frame(maxHeight: .infinity)
                            .background(active ? theme.accentColor : .clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxHeight: .infinity)

            statusText(n.folder + "/" + n.fileName, leadingBorder: true)
            Spacer()
            statusText("Ln \(model.activeBlock + 1), Col 1")
            statusText("markdown", leadingBorder: true)

            HoverButton(action: { openSettings() }) { hovering in
                HStack(spacing: 6) {
                    Image(systemName: syncFolder.isSet ? "folder.fill" : "folder.badge.plus")
                        .font(.system(size: 10))
                        .foregroundStyle(syncFolder.isSet ? theme.accentColor : theme.faintColor)
                    Text(syncFolder.folderName ?? "Sync folder")
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                }
                .foregroundStyle(hovering ? theme.fgColor : theme.fgMutedColor)
                .padding(.horizontal, 12)
                .frame(maxHeight: .infinity)
                .background(hovering ? theme.elevatedColor : .clear)
                .overlay(alignment: .leading) {
                    Rectangle().fill(theme.borderColor).frame(width: 1)
                }
            }

            HoverButton(action: { model.themePickerOpen.toggle() }) { hovering in
                HStack(spacing: 7) {
                    Circle().fill(theme.accentColor).frame(width: 7, height: 7)
                    Text(theme.label)
                        .font(.system(size: 11, design: .monospaced))
                    Text("▲").font(.system(size: 8)).foregroundStyle(theme.faintColor)
                }
                .foregroundStyle(hovering ? theme.fgColor : theme.fgMutedColor)
                .padding(.horizontal, 14)
                .frame(maxHeight: .infinity)
                .background(hovering ? theme.elevatedColor : .clear)
                .overlay(alignment: .leading) {
                    Rectangle().fill(theme.borderColor).frame(width: 1)
                }
            }
        }
        .frame(height: 30)
        .background(theme.sidebarColor)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.borderColor).frame(height: 1)
        }
    }

    private func statusText(_ s: String, leadingBorder: Bool = false) -> some View {
        Text(s)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(theme.faintColor)
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .leading) {
                if leadingBorder {
                    Rectangle().fill(theme.borderColor).frame(width: 1)
                }
            }
    }
}
