import SwiftUI

public enum ThemeName: String, CaseIterable, Identifiable, Sendable {
    case tokyonight, catppuccin, gruvbox, everforest
    case ubuntu, osakaJade, catppuccinLatte, pulsar, archwave
    public var id: String { rawValue }
}

/// An Omarchy palette. Hex values are ported verbatim from the design.
public struct Theme: Sendable {
    public let name: ThemeName
    public let label: String
    public let short: String
    /// Whether this palette is dark (drives `preferredColorScheme`).
    public let isDark: Bool

    public let bg: String
    public let sidebar: String
    public let elevated: String
    public let border: String
    public let fg: String
    public let fgMuted: String
    public let faint: String
    public let accent: String
    public let accent2: String
    public let red: String
    public let yellow: String
    public let magenta: String
    public let orange: String

    // MARK: SwiftUI colors
    public var bgColor: Color { Color(hex: bg) }
    public var sidebarColor: Color { Color(hex: sidebar) }
    public var elevatedColor: Color { Color(hex: elevated) }
    public var borderColor: Color { Color(hex: border) }
    public var fgColor: Color { Color(hex: fg) }
    public var fgMutedColor: Color { Color(hex: fgMuted) }
    public var faintColor: Color { Color(hex: faint) }
    public var accentColor: Color { Color(hex: accent) }
    public var accent2Color: Color { Color(hex: accent2) }
    public var redColor: Color { Color(hex: red) }
    public var yellowColor: Color { Color(hex: yellow) }
    public var magentaColor: Color { Color(hex: magenta) }
    public var orangeColor: Color { Color(hex: orange) }
    public var selectionColor: Color { accentColor.opacity(0.16) }

    /// The subtle tinted background used behind the active edit block / palette selection.
    public func accentTint(_ pct: Double) -> Color { accentColor.opacity(pct) }

    public func color(forBar key: String) -> Color {
        switch key {
        case "accent": return accentColor
        case "accent2": return accent2Color
        case "red": return redColor
        case "yellow": return yellowColor
        case "magenta": return magentaColor
        case "orange": return orangeColor
        case "faint": return faintColor
        default: return faintColor
        }
    }
}

extension Theme {
    public static let all: [ThemeName: Theme] = [
        .tokyonight: Theme(
            name: .tokyonight, label: "Tokyo Night", short: "Tokyo", isDark: true,
            bg: "#1a1b26", sidebar: "#16161e", elevated: "#1f2335",
            border: "#2a2e42", fg: "#c0caf5", fgMuted: "#9aa5ce",
            faint: "#565f89", accent: "#7aa2f7", accent2: "#9ece6a",
            red: "#f7768e", yellow: "#e0af68", magenta: "#bb9af7",
            orange: "#ff9e64"),
        .catppuccin: Theme(
            name: .catppuccin, label: "Catppuccin", short: "Catppuccin", isDark: true,
            bg: "#1e1e2e", sidebar: "#181825", elevated: "#262638",
            border: "#313244", fg: "#cdd6f4", fgMuted: "#a6adc8",
            faint: "#6c7086", accent: "#89b4fa", accent2: "#a6e3a1",
            red: "#f38ba8", yellow: "#f9e2af", magenta: "#cba6f7",
            orange: "#fab387"),
        .gruvbox: Theme(
            name: .gruvbox, label: "Gruvbox", short: "Gruvbox", isDark: true,
            bg: "#282828", sidebar: "#1d2021", elevated: "#32302f",
            border: "#3c3836", fg: "#ebdbb2", fgMuted: "#d5c4a1",
            faint: "#928374", accent: "#83a598", accent2: "#b8bb26",
            red: "#fb4934", yellow: "#fabd2f", magenta: "#d3869b",
            orange: "#fe8019"),
        .everforest: Theme(
            name: .everforest, label: "Everforest", short: "Everforest", isDark: true,
            bg: "#2d353b", sidebar: "#232a2e", elevated: "#343f44",
            border: "#3d484d", fg: "#d3c6aa", fgMuted: "#a6b0a0",
            faint: "#859289", accent: "#7fbbb3", accent2: "#a7c080",
            red: "#e67e80", yellow: "#dbbc7f", magenta: "#d699b6",
            orange: "#e69875"),

        // Ported from todarchy-ios (todo app). The todo palette's field roles
        // map onto Notakase's like so: sidebar←bgElev, elevated←panel,
        // fgMuted←fgDim, faint←fgMute, accent2←success, red←danger, yellow←warn,
        // magenta←purple.
        .ubuntu: Theme(
            name: .ubuntu, label: "Ubuntu", short: "Ubuntu", isDark: true,
            bg: "#0a0a0f", sidebar: "#14141c", elevated: "#22222e",
            border: "#26262f", fg: "#eceaea", fgMuted: "#d9d9d9",
            faint: "#aea79f", accent: "#e95420", accent2: "#a6d98e",
            red: "#ef6c6c", yellow: "#f9c784", magenta: "#bb9af7",
            orange: "#e95420"),
        .osakaJade: Theme(
            name: .osakaJade, label: "Osaka Jade", short: "Osaka", isDark: true,
            bg: "#111c18", sidebar: "#0d1712", elevated: "#1b2a23",
            border: "#23372b", fg: "#c1c497", fgMuted: "#a7aa84",
            faint: "#6e8377", accent: "#509475", accent2: "#63b07a",
            red: "#ff5345", yellow: "#e5c736", magenta: "#d2689c",
            orange: "#db9f9c"),
        .catppuccinLatte: Theme(
            name: .catppuccinLatte, label: "Catppuccin Latte", short: "Latte",
            isDark: false,
            bg: "#eff1f5", sidebar: "#e6e9ef", elevated: "#e6e9ef",
            border: "#ccd0da", fg: "#4c4f69", fgMuted: "#5c5f77",
            faint: "#6c6f85", accent: "#1e66f5", accent2: "#40a02b",
            red: "#d20f39", yellow: "#df8e1d", magenta: "#8839ef",
            orange: "#fe640b"),
        .pulsar: Theme(
            name: .pulsar, label: "Pulsar", short: "Pulsar", isDark: true,
            bg: "#0a0314", sidebar: "#070210", elevated: "#1d0f30",
            border: "#2e1a47", fg: "#e0e6ff", fgMuted: "#b8bfe0",
            faint: "#8f86b5", accent: "#b82aff", accent2: "#70d674",
            red: "#ff5779", yellow: "#f2e42e", magenta: "#b82aff",
            orange: "#ff7a59"),
        .archwave: Theme(
            name: .archwave, label: "Archwave", short: "Archwave", isDark: true,
            bg: "#1a0d2e", sidebar: "#140a24", elevated: "#2d1b4e",
            border: "#3a2560", fg: "#d4a5ff", fgMuted: "#be9be6",
            faint: "#8a6fb0", accent: "#f4a5ff", accent2: "#8ffef4",
            red: "#ff6ec7", yellow: "#f9f871", magenta: "#f4a5ff",
            orange: "#ff9e7a"),
    ]

    public static let order: [ThemeName] = [
        .tokyonight, .catppuccin, .gruvbox, .everforest,
        .ubuntu, .osakaJade, .catppuccinLatte, .pulsar, .archwave,
    ]

    public static func named(_ name: ThemeName) -> Theme { all[name]! }
}

extension Color {
    /// Create a color from a `#rrggbb` hex string.
    public init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b: Double
        if s.count == 6 {
            r = Double((v & 0xFF0000) >> 16) / 255
            g = Double((v & 0x00FF00) >> 8) / 255
            b = Double(v & 0x0000FF) / 255
        } else {
            r = 0
            g = 0
            b = 0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
