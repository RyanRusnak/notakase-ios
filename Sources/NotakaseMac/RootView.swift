import NotakaseCore
import SwiftUI

struct RootView: View {
    @ObservedObject var store: NotakaseStore
    @EnvironmentObject var syncFolder: SyncFolder
    @EnvironmentObject var todokase: TodokaseTasks
    @StateObject private var model: DesktopModel

    init(store: NotakaseStore) {
        self.store = store
        _model = StateObject(wrappedValue: DesktopModel(store: store))
    }

    private var theme: Theme { store.theme }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(model: model, store: store)
                .frame(width: 266)

            VStack(spacing: 0) {
                TopBar(model: model, theme: theme)
                ScrollView {
                    HStack {
                        Spacer(minLength: 0)
                        DocumentView(model: model, theme: theme)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 44)
                    .padding(.top, 52)
                    .padding(.bottom, 140)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                StatusBar(model: model, theme: theme)
            }
            .background(theme.bgColor)
        }
        .background(theme.bgColor)
        .foregroundStyle(theme.fgColor)
        .overlay(alignment: .bottomTrailing) {
            if model.themePickerOpen {
                ThemePickerView(model: model, theme: theme)
            }
        }
        .overlay {
            if model.keysOpen {
                KeyboardSheetView(theme: theme) { model.keysOpen = false }
            }
        }
        .overlay {
            if model.paletteOpen {
                CommandPaletteView(model: model, theme: theme)
            }
        }
        .overlay {
            if model.sendToOpen {
                SendToView(model: model, theme: theme)
            }
        }
        .onWikiLink { title in model.openByTitle(title) }
        .background(
            KeyCatcher { event in model.handleKey(event) }
                .frame(width: 0, height: 0)
        )
        .animation(.easeOut(duration: 0.12), value: model.paletteOpen)
        .animation(.easeOut(duration: 0.12), value: model.sendToOpen)
        .animation(.easeOut(duration: 0.12), value: model.keysOpen)
        .animation(.easeOut(duration: 0.12), value: model.themePickerOpen)
        .preferredColorScheme(theme.isDark ? .dark : .light)
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
        }
        .onChange(of: syncFolder.folderURL) { _, url in
            store.applySyncFolder(url)
        }
    }
}

// MARK: - Top bar

struct TopBar: View {
    @ObservedObject var model: DesktopModel
    let theme: Theme

    private let hints: [(String, String)] = [
        ("j / k", "nav"), ("/", "search"), ("t", "theme"),
    ]

    var body: some View {
        let n = model.current
        HStack(spacing: 14) {
            Text("notakase  ›  \((n.dir + [n.title]).joined(separator: "  ›  "))")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.faintColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 9) {
                ForEach(hints, id: \.0) { hint in
                    HStack(spacing: 5) {
                        Text(hint.0)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(theme.fgMutedColor)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(theme.elevatedColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(theme.borderColor, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text(hint.1)
                            .font(.system(size: 10.5))
                            .foregroundStyle(theme.faintColor)
                    }
                }
                HoverButton(action: { model.keysOpen = true }) { hovering in
                    Text("?")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.fgMutedColor)
                        .frame(width: 24, height: 24)
                        .background(theme.elevatedColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    hovering ? theme.accentColor : theme.borderColor,
                                    lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Text("\(n.wordCount) words · \(n.readMinutes) min")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.faintColor)
                .lineLimit(1)
                .padding(.leading, 14)
                .overlay(alignment: .leading) {
                    Rectangle().fill(theme.borderColor).frame(width: 1)
                }
        }
        .padding(.horizontal, 18)
        .frame(height: 46)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.borderColor).frame(height: 1)
        }
    }
}

/// A button that reports its hover state to the label builder.
struct HoverButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: (Bool) -> Label
    @State private var hovering = false

    var body: some View {
        Button(action: action) { label(hovering) }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
    }
}
