import SwiftUI

/// The custom URL scheme used to make `[[wikilinks]]` tappable through the
/// SwiftUI `openURL` environment. Install `WikiLinkHandler` on an ancestor.
public enum WikiLink {
    public static let scheme = "notakase"

    public static func url(forTitle title: String) -> URL? {
        let encoded =
            title.addingPercentEncoding(
                withAllowedCharacters: .urlPathAllowed) ?? title
        return URL(string: "\(scheme)://wiki/\(encoded)")
    }

    /// Extract the note title from a wikilink URL, if it is one.
    public static func title(from url: URL) -> String? {
        guard url.scheme == scheme else { return nil }
        let path = url.path.trimmingCharacters(
            in: CharacterSet(charactersIn: "/"))
        return path.removingPercentEncoding ?? path
    }
}

extension View {
    /// Intercept `[[wikilink]]` taps and route them to `handler` (by note title).
    public func onWikiLink(_ handler: @escaping (String) -> Void) -> some View {
        environment(
            \.openURL,
            OpenURLAction { url in
                if let title = WikiLink.title(from: url) {
                    handler(title)
                    return .handled
                }
                return .discarded
            })
    }
}

// MARK: - Inline

extension Markdown {
    /// Build a styled `AttributedString` from inline spans.
    public static func attributed(
        _ text: String, theme: Theme, baseSize: CGFloat
    ) -> AttributedString {
        var result = AttributedString()
        for span in parseInline(text) {
            switch span {
            case .text(let s):
                result += AttributedString(s)
            case .bold(let s):
                var a = AttributedString(s)
                a.font = Typo.mono(baseSize, weight: .semibold)
                a.foregroundColor = theme.fgColor
                result += a
            case .italic(let s):
                var a = AttributedString(s)
                a.font = Typo.mono(baseSize).italic()
                result += a
            case .code(let s):
                var a = AttributedString(s)
                a.font = Typo.mono(baseSize * 0.82)
                a.foregroundColor = theme.accent2Color
                a.backgroundColor = theme.elevatedColor
                result += a
            case .wikiLink(let target, let label):
                var a = AttributedString(label)
                a.foregroundColor = theme.accentColor
                a.underlineStyle = .single
                if let url = WikiLink.url(forTitle: target) { a.link = url }
                result += a
            case .link(let label, _):
                var a = AttributedString(label)
                a.foregroundColor = theme.accentColor
                a.underlineStyle = .single
                result += a
            }
        }
        return result
    }
}

/// One line of inline markdown as a `Text`.
public struct InlineText: View {
    let text: String
    let theme: Theme
    let baseSize: CGFloat

    public init(_ text: String, theme: Theme, baseSize: CGFloat) {
        self.text = text
        self.theme = theme
        self.baseSize = baseSize
    }

    public var body: some View {
        Text(Markdown.attributed(text, theme: theme, baseSize: baseSize))
            .font(Typo.mono(baseSize))
            .foregroundStyle(theme.fgColor)
            .tint(theme.accentColor)
    }
}

// MARK: - Rendered block

/// A single markdown block rendered as native SwiftUI (WYSIWYG).
public struct BlockView: View {
    let block: Block
    let theme: Theme
    let baseSize: CGFloat

    public init(block: Block, theme: Theme, baseSize: CGFloat = 18.5) {
        self.block = block
        self.theme = theme
        self.baseSize = baseSize
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 31
        case 2: return 23
        case 3: return 19
        case 4: return 17
        case 5: return 15
        default: return 14
        }
    }

    public var body: some View {
        switch block {
        case .heading(let level, let text, _):
            InlineText(text, theme: theme, baseSize: headingSize(level))
                .font(Typo.mono(headingSize(level), weight: .semibold))
                .foregroundStyle(theme.fgColor)
                .tracking(-0.3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, level == 1 ? 0 : 18)
                .padding(.bottom, level == 1 ? 12 : 8)

        case .paragraph(let text, _):
            InlineText(text, theme: theme, baseSize: baseSize)
                .lineSpacing(baseSize * 0.42)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)

        case .quote(let text, _):
            HStack(spacing: 0) {
                Rectangle().fill(theme.accentColor).frame(width: 3)
                InlineText(text, theme: theme, baseSize: baseSize)
                    .italic()
                    .foregroundStyle(theme.fgMutedColor)
                    .lineSpacing(baseSize * 0.36)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 16)
            }
            .padding(.vertical, 2)
            .padding(.bottom, 16)

        case .hr:
            Rectangle().fill(theme.borderColor).frame(height: 1)
                .padding(.vertical, 22)

        case .image(let alt, _, _):
            ZStack {
                theme.elevatedColor
                Text(alt.isEmpty ? "image" : alt)
                    .font(Typo.mono(11))
                    .foregroundStyle(theme.faintColor)
                    .padding(.horizontal, 11).padding(.vertical, 5)
                    .background(theme.bgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.borderColor, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.borderColor, lineWidth: 1)
            )
            .padding(.bottom, 18)

        case .code(let lang, let text, _):
            if lang.lowercased() == "todokase" {
                TodokaseBlockView(config: text, theme: theme, baseSize: baseSize)
            } else {
                codeBlock(lang: lang, text: text)
            }

        case .list(let ordered, let items, _):
            listBlock(ordered: ordered, items: items)
        }
    }

    @ViewBuilder
    private func codeBlock(lang: String, text: String) -> some View {
        let lines = text.components(separatedBy: "\n")
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, ln in
                    let isComment =
                        ln.range(
                            of: "^\\s*(#|//)", options: .regularExpression)
                        != nil
                    Text(ln.isEmpty ? " " : ln)
                        .font(Typo.mono(13.5))
                        .foregroundStyle(
                            isComment ? theme.faintColor : theme.fgColor
                        )
                        .italic(isComment)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if !lang.isEmpty {
                Text(lang.uppercased())
                    .font(Typo.mono(10))
                    .tracking(0.8)
                    .foregroundStyle(theme.faintColor)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 15)
        .background(theme.sidebarColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.borderColor, lineWidth: 1)
        )
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private func listBlock(ordered: Bool, items: [ListItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                HStack(alignment: .top, spacing: 10) {
                    if let done = item.task {
                        Checkbox(done: done, theme: theme)
                            .padding(.top, 3)
                        InlineText(
                            item.content, theme: theme, baseSize: baseSize
                        )
                        .strikethrough(done, color: theme.faintColor)
                        .foregroundStyle(done ? theme.faintColor : theme.fgColor)
                        .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(ordered ? "\(idx + 1)." : "•")
                            .font(Typo.mono(baseSize))
                            .foregroundStyle(theme.faintColor)
                            .frame(minWidth: ordered ? 22 : 14, alignment: .leading)
                        InlineText(
                            item.content, theme: theme, baseSize: baseSize
                        )
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.bottom, 18)
    }
}

/// A task-list checkbox matching the design (accent2 fill + tick when done).
struct Checkbox: View {
    let done: Bool
    let theme: Theme
    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(done ? theme.accent2Color : Color.clear)
            .frame(width: 17, height: 17)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(
                        done ? theme.accent2Color : theme.faintColor,
                        lineWidth: 1.5)
            )
            .overlay(
                Group {
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(theme.bgColor)
                    }
                }
            )
    }
}

// MARK: - Source block (macOS edit view)

/// The active block rendered as raw markdown source, with a modal caret.
public struct SourceBlockView: View {
    let block: Block
    let theme: Theme
    let insertMode: Bool

    public init(block: Block, theme: Theme, insertMode: Bool) {
        self.block = block
        self.theme = theme
        self.insertMode = insertMode
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(theme.accentColor).frame(width: 2)
            VStack(alignment: .leading, spacing: 2) {
                let lines = block.raw.components(separatedBy: "\n")
                ForEach(Array(lines.enumerated()), id: \.offset) { idx, ln in
                    HStack(alignment: .center, spacing: 0) {
                        Text(sourceAttributed(ln))
                            .font(Typo.mono(14.5))
                            .fixedSize(horizontal: false, vertical: true)
                        if idx == lines.count - 1 {
                            BlinkingCaret(
                                color: theme.accentColor,
                                width: insertMode ? 2 : 8,
                                opacity: insertMode ? 1 : 0.55)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
        }
        .background(theme.accentColor.opacity(0.08))
        .clipShape(
            .rect(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: 8, topTrailingRadius: 8)
        )
        .padding(.bottom, 8)
    }

    /// Tint markdown punctuation (magenta) vs. content (fg), like the design.
    private func sourceAttributed(_ line: String) -> AttributedString {
        var result = AttributedString()
        let tokens = Set(["**", "*", "`", "[[", "]]", "[", "]", "(", ")", "~~"])
        // split keeping delimiters
        let pattern = "(\\*\\*|\\*|`|\\[\\[|\\]\\]|\\[|\\]|\\(|\\)|~~)"
        let ns = line as NSString
        var last = 0
        if let re = try? NSRegularExpression(pattern: pattern) {
            re.enumerateMatches(
                in: line, range: NSRange(location: 0, length: ns.length)
            ) { m, _, _ in
                guard let m else { return }
                if m.range.location > last {
                    var a = AttributedString(
                        ns.substring(
                            with: NSRange(
                                location: last,
                                length: m.range.location - last)))
                    a.foregroundColor = theme.fgColor
                    result += a
                }
                var a = AttributedString(ns.substring(with: m.range))
                a.foregroundColor = theme.magentaColor
                result += a
                last = m.range.location + m.range.length
            }
        }
        if last < ns.length {
            var a = AttributedString(
                ns.substring(
                    with: NSRange(location: last, length: ns.length - last)))
            a.foregroundColor = theme.fgColor
            result += a
        }
        _ = tokens
        return result
    }
}

/// A blinking block/bar caret.
public struct BlinkingCaret: View {
    let color: Color
    let width: CGFloat
    let opacity: Double
    @State private var on = true

    public init(color: Color, width: CGFloat, opacity: Double) {
        self.color = color
        self.width = width
        self.opacity = opacity
    }

    public var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width, height: 18)
            .opacity(on ? opacity : 0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.01).repeatForever(
                        autoreverses: true).delay(0.5)
                ) { on = false }
            }
            .padding(.leading, 1)
    }
}
