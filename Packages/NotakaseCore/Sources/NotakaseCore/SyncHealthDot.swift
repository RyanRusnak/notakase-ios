import SwiftUI

/// A small traffic-light dot reflecting the sync folder's health, with the
/// last-successful-sync (or error) surfaced on hover. Shared by the macOS
/// Settings window and the iOS settings sheet.
public struct SyncHealthDot: View {
    @ObservedObject var store: NotakaseStore
    let theme: Theme

    public init(store: NotakaseStore, theme: Theme) {
        self.store = store
        self.theme = theme
    }

    private var color: Color {
        switch store.syncHealth {
        case .ok: return theme.accent2Color
        case .failing: return theme.redColor
        case .unknown: return theme.faintColor
        }
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(color.opacity(0.35), lineWidth: 3).blur(radius: 1))
            .help(store.syncStatusDescription)
            .accessibilityLabel(Text(store.syncStatusDescription))
    }
}

/// The health dot plus a compact "synced 2m ago" label — a visible
/// at-a-glance last-sync indicator (unlike the dot's hover-only tooltip).
public struct SyncStatusLabel: View {
    @ObservedObject var store: NotakaseStore
    let theme: Theme
    let fontSize: CGFloat

    public init(store: NotakaseStore, theme: Theme, fontSize: CGFloat = 11) {
        self.store = store
        self.theme = theme
        self.fontSize = fontSize
    }

    public var body: some View {
        HStack(spacing: 5) {
            SyncHealthDot(store: store, theme: theme)
            Text(store.syncStatusShort)
                .font(Typo.mono(fontSize))
                .foregroundStyle(theme.faintColor)
                .lineLimit(1)
        }
        .help(store.syncStatusDescription)
    }
}
