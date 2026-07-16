import NotakaseCore
import SwiftUI

// MARK: - Command palette

struct CommandPaletteView: View {
    @ObservedObject var model: DesktopModel
    let theme: Theme
    @FocusState private var focused: Bool

    var body: some View {
        let items = model.paletteItems()
        let sel = min(model.selIndex, max(0, items.count - 1))
        ZStack(alignment: .top) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { model.paletteOpen = false }
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text("⌕").foregroundStyle(theme.faintColor).font(.system(size: 14))
                    TextField("Jump to a note or run a command…", text: $model.pq)
                        .textFieldStyle(.plain)
                        .font(Typo.mono(14))
                        .foregroundStyle(theme.fgColor)
                        .focused($focused)
                        .onChange(of: model.pq) { model.selIndex = 0 }
                    Text("esc")
                        .font(Typo.mono(10))
                        .foregroundStyle(theme.faintColor)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(theme.borderColor, lineWidth: 1))
                }
                .padding(.horizontal, 18).padding(.vertical, 15)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(theme.borderColor).frame(height: 1)
                }

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, it in
                            Button(action: it.action) {
                                HStack(spacing: 11) {
                                    Text(it.icon)
                                        .font(.system(size: 10))
                                        .foregroundStyle(theme.faintColor)
                                        .frame(width: 16)
                                    Text(it.label)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Text(it.hint)
                                        .font(Typo.mono(10.5))
                                        .foregroundStyle(theme.faintColor)
                                }
                                .font(Typo.mono(13))
                                .foregroundStyle(i == sel ? theme.fgColor : theme.fgMutedColor)
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    i == sel ? theme.accentColor.opacity(0.16) : .clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 320)
            }
            .frame(width: 560)
            .background(theme.elevatedColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(theme.borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.55), radius: 35, y: 24)
            .padding(.top, 120)
        }
        .onAppear { focused = true }
    }
}

// MARK: - Send-to (move note) picker

struct SendToView: View {
    @ObservedObject var model: DesktopModel
    let theme: Theme
    @FocusState private var focused: Bool

    var body: some View {
        let dests = model.sendToDestinations()
        let sel = min(model.sendToSel, max(0, dests.count - 1))
        ZStack(alignment: .top) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { model.sendToOpen = false }
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text("→").foregroundStyle(theme.accentColor).font(.system(size: 14))
                    TextField("Send “\(model.current.title)” to…", text: $model.sendToQuery)
                        .textFieldStyle(.plain)
                        .font(Typo.mono(14))
                        .foregroundStyle(theme.fgColor)
                        .focused($focused)
                        .onChange(of: model.sendToQuery) { model.sendToSel = 0 }
                    Text("esc")
                        .font(Typo.mono(10))
                        .foregroundStyle(theme.faintColor)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(theme.borderColor, lineWidth: 1))
                }
                .padding(.horizontal, 18).padding(.vertical, 15)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(theme.borderColor).frame(height: 1)
                }

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(dests.enumerated()), id: \.offset) { i, dir in
                            Button(action: { model.sendCurrentTo(dir) }) {
                                HStack(spacing: 11) {
                                    Text(dir.isEmpty ? "⌂" : "▤")
                                        .font(.system(size: 11))
                                        .foregroundStyle(theme.faintColor)
                                        .frame(width: 16)
                                    Text(model.label(forDir: dir))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .font(Typo.mono(13))
                                .foregroundStyle(i == sel ? theme.fgColor : theme.fgMutedColor)
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    i == sel ? theme.accentColor.opacity(0.16) : .clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 300)
            }
            .frame(width: 460)
            .background(theme.elevatedColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(theme.borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.55), radius: 35, y: 24)
            .padding(.top, 120)
        }
        .onAppear { focused = true }
    }
}

// MARK: - Keyboard shortcuts sheet

struct KeyboardSheetView: View {
    let theme: Theme
    let close: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 34), GridItem(.flexible())]

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Circle().fill(theme.accentColor).frame(width: 9, height: 9)
                    Text("Keyboard shortcuts")
                        .font(Typo.mono(16, weight: .semibold))
                        .foregroundStyle(theme.fgColor)
                    Text("— from the Omarchy TUI")
                        .font(Typo.mono(11))
                        .foregroundStyle(theme.faintColor)
                    Spacer()
                    Text("? or esc")
                        .font(Typo.mono(10))
                        .foregroundStyle(theme.faintColor)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(theme.borderColor, lineWidth: 1))
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(theme.borderColor).frame(height: 1)
                }

                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                        ForEach(Shortcuts.groups) { grp in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(grp.title.uppercased())
                                    .font(.system(size: 10)).tracking(1.3)
                                    .foregroundStyle(theme.accentColor)
                                    .padding(.bottom, 9)
                                ForEach(grp.rows) { r in
                                    HStack(spacing: 12) {
                                        HStack(spacing: 4) {
                                            ForEach(r.keys, id: \.self) { k in
                                                keyCap(k)
                                            }
                                        }
                                        .frame(width: 74, alignment: .leading)
                                        Text(r.action)
                                            .font(Typo.mono(12.5))
                                            .foregroundStyle(theme.fgMutedColor)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 5)
                                }
                            }
                            .padding(.top, 18)
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 22)
                }
            }
            .frame(width: 680, height: 560)
            .background(theme.elevatedColor)
            .overlay(
                RoundedRectangle(cornerRadius: 16).stroke(theme.borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.6), radius: 40, y: 24)
        }
    }

    private func keyCap(_ k: String) -> some View {
        Text(k)
            .font(Typo.mono(11))
            .foregroundStyle(theme.fgColor)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(theme.sidebarColor)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(theme.borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - Theme picker

struct ThemePickerView: View {
    @ObservedObject var model: DesktopModel
    let theme: Theme

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { model.themePickerOpen = false }
            VStack(alignment: .leading, spacing: 0) {
                Text("THEME · PRESS T")
                    .font(.system(size: 9.5)).tracking(1.1)
                    .foregroundStyle(theme.faintColor)
                    .padding(.horizontal, 14).padding(.top, 11).padding(.bottom, 7)
                VStack(spacing: 0) {
                    ForEach(Theme.order) { id in
                        let t = Theme.named(id)
                        let active = id == theme.name
                        HoverButton(action: { model.setTheme(id) }) { hovering in
                            HStack(spacing: 10) {
                                Circle().fill(t.accentColor).frame(width: 11, height: 11)
                                    .overlay(
                                        Circle().stroke(
                                            active ? t.accentColor.opacity(0.35) : .clear,
                                            lineWidth: 2
                                        ).scaleEffect(1.4))
                                Text(t.label)
                                    .font(Typo.mono(12))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                if active {
                                    Text("✓").foregroundStyle(theme.accentColor)
                                        .font(.system(size: 12))
                                }
                            }
                            .foregroundStyle(active || hovering ? theme.fgColor : theme.fgMutedColor)
                            .padding(.horizontal, 10).padding(.vertical, 9)
                            .background(
                                active
                                    ? theme.accentColor.opacity(0.14)
                                    : (hovering ? theme.elevatedColor.opacity(0.6) : .clear)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal, 6).padding(.bottom, 6)
            }
            .frame(width: 212)
            .background(theme.elevatedColor)
            .overlay(
                RoundedRectangle(cornerRadius: 11).stroke(theme.borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .shadow(color: .black.opacity(0.5), radius: 22, y: 16)
            .padding(.trailing, 14).padding(.bottom, 38)
        }
    }
}
