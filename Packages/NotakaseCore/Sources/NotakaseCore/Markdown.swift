import Foundation

/// A parsed markdown block. Ported from the design's `parseBlocks`.
public enum Block: Equatable {
    case heading(level: Int, text: String, raw: String)
    case paragraph(text: String, raw: String)
    case quote(text: String, raw: String)
    case hr(raw: String)
    case image(alt: String, src: String, raw: String)
    case code(lang: String, text: String, raw: String)
    case list(ordered: Bool, items: [ListItem], raw: String)

    public var raw: String {
        switch self {
        case .heading(_, _, let r), .paragraph(_, let r), .quote(_, let r),
            .hr(let r), .image(_, _, let r), .code(_, _, let r),
            .list(_, _, let r):
            return r
        }
    }
}

public struct ListItem: Equatable {
    public let content: String
    /// nil = plain bullet, true = checked task, false = unchecked task.
    public let task: Bool?
    public init(content: String, task: Bool?) {
        self.content = content
        self.task = task
    }
}

public enum Markdown {
    private static func matches(_ pattern: String, _ s: String) -> Bool {
        s.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isBlockStart(_ t: String) -> Bool {
        matches("^#{1,6}\\s", t) || matches("^>\\s?", t)
            || matches("^(-|\\*|\\+)\\s", t) || matches("^\\d+\\.\\s", t)
            || t.hasPrefix("```") || matches("^(-{3,}|\\*{3,})$", t)
            || matches("^!\\[.*\\]\\(.*\\)$", t)
    }

    /// Split markdown into a flat list of blocks.
    public static func parse(_ md: String) -> [Block] {
        let lines = md.components(separatedBy: "\n")
        var out: [Block] = []
        var i = 0
        while i < lines.count {
            let raw = lines[i]
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.isEmpty {
                i += 1
                continue
            }

            // fenced code
            if t.hasPrefix("```") {
                let lang = String(t.dropFirst(3)).trimmingCharacters(
                    in: .whitespaces)
                i += 1
                var buf: [String] = []
                while i < lines.count,
                    !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(
                        "```")
                {
                    buf.append(lines[i])
                    i += 1
                }
                i += 1
                let text = buf.joined(separator: "\n")
                out.append(
                    .code(
                        lang: lang, text: text,
                        raw: "```\(lang)\n\(text)\n```"))
                continue
            }

            // heading
            if let m = firstMatch("^(#{1,6})\\s+(.*)$", t) {
                let hashes = m[1]
                out.append(
                    .heading(level: hashes.count, text: m[2], raw: raw))
                i += 1
                continue
            }

            // blockquote
            if matches("^>\\s?", t) {
                var buf: [String] = []
                var org: [String] = []
                while i < lines.count,
                    matches(
                        "^>\\s?",
                        lines[i].trimmingCharacters(in: .whitespaces))
                {
                    org.append(lines[i])
                    buf.append(
                        lines[i].replacingOccurrences(
                            of: "^\\s*>\\s?", with: "",
                            options: .regularExpression))
                    i += 1
                }
                out.append(
                    .quote(
                        text: buf.joined(separator: " "),
                        raw: org.joined(separator: "\n")))
                continue
            }

            // image
            if let m = firstMatch("^!\\[([^\\]]*)\\]\\(([^)]*)\\)$", t) {
                out.append(.image(alt: m[1], src: m[2], raw: raw))
                i += 1
                continue
            }

            // list (ordered or unordered, with optional task markers)
            if matches("^(-|\\*|\\+)\\s", t) || matches("^\\d+\\.\\s", t) {
                let ordered = matches("^\\d+\\.\\s", t)
                var items: [ListItem] = []
                var org: [String] = []
                while i < lines.count {
                    let lt = lines[i].trimmingCharacters(in: .whitespaces)
                    if matches("^(-|\\*|\\+)\\s", lt)
                        || matches("^\\d+\\.\\s", lt)
                    {
                        org.append(lines[i])
                        var c = lt.replacingOccurrences(
                            of: "^(-|\\*|\\+)\\s+", with: "",
                            options: .regularExpression)
                        c = c.replacingOccurrences(
                            of: "^\\d+\\.\\s+", with: "",
                            options: .regularExpression)
                        var task: Bool? = nil
                        if let tm = firstMatch("^\\[([ xX])\\]\\s+(.*)$", c) {
                            task = tm[1].lowercased() == "x"
                            c = tm[2]
                        }
                        items.append(ListItem(content: c, task: task))
                        i += 1
                    } else {
                        break
                    }
                }
                out.append(
                    .list(
                        ordered: ordered, items: items,
                        raw: org.joined(separator: "\n")))
                continue
            }

            // horizontal rule
            if matches("^(-{3,}|\\*{3,})$", t) {
                out.append(.hr(raw: raw))
                i += 1
                continue
            }

            // paragraph — gather until blank line or the next block start
            var org: [String] = []
            while i < lines.count,
                !lines[i].trimmingCharacters(in: .whitespaces).isEmpty,
                !isBlockStart(lines[i].trimmingCharacters(in: .whitespaces))
            {
                org.append(lines[i])
                i += 1
            }
            out.append(
                .paragraph(
                    text: org.joined(separator: " "),
                    raw: org.joined(separator: "\n")))
        }
        return out
    }

    /// Returns the capture groups (including group 0) of the first match, or nil.
    private static func firstMatch(_ pattern: String, _ s: String) -> [String]?
    {
        guard
            let re = try? NSRegularExpression(pattern: pattern),
            let m = re.firstMatch(
                in: s, range: NSRange(s.startIndex..., in: s))
        else { return nil }
        var groups: [String] = []
        for g in 0..<m.numberOfRanges {
            if let r = Range(m.range(at: g), in: s) {
                groups.append(String(s[r]))
            } else {
                groups.append("")
            }
        }
        return groups
    }
}

// MARK: - Inline parsing

/// A span of inline markdown.
public enum InlineSpan: Equatable {
    case text(String)
    case code(String)
    case bold(String)
    case italic(String)
    case wikiLink(target: String, label: String)
    case link(label: String, href: String)
}

extension Markdown {
    /// Parse inline markdown into spans: `code`, **bold**, *em*, [[wiki]], [link](href).
    public static func parseInline(_ text: String) -> [InlineSpan] {
        let pattern =
            "(`[^`]+`)|(\\*\\*[^*]+\\*\\*)|(\\*[^*\\n]+\\*)|(\\[\\[[^\\]]+\\]\\])|(\\[[^\\]]+\\]\\([^)]+\\))"
        guard let re = try? NSRegularExpression(pattern: pattern) else {
            return [.text(text)]
        }
        let ns = text as NSString
        var out: [InlineSpan] = []
        var last = 0
        re.enumerateMatches(
            in: text, range: NSRange(location: 0, length: ns.length)
        ) { match, _, _ in
            guard let match else { return }
            let whole = match.range
            if whole.location > last {
                out.append(
                    .text(
                        ns.substring(
                            with: NSRange(
                                location: last, length: whole.location - last)
                        )))
            }
            let s = ns.substring(with: whole)
            if match.range(at: 1).location != NSNotFound {
                out.append(.code(String(s.dropFirst().dropLast())))
            } else if match.range(at: 2).location != NSNotFound {
                out.append(.bold(String(s.dropFirst(2).dropLast(2))))
            } else if match.range(at: 3).location != NSNotFound {
                out.append(.italic(String(s.dropFirst().dropLast())))
            } else if match.range(at: 4).location != NSNotFound {
                let inner = String(s.dropFirst(2).dropLast(2))
                let parts = inner.components(separatedBy: "|")
                out.append(
                    .wikiLink(
                        target: parts.first ?? inner,
                        label: parts.last ?? inner))
            } else if match.range(at: 5).location != NSNotFound {
                if let m = firstMatch("^\\[([^\\]]+)\\]\\(([^)]+)\\)$", s) {
                    out.append(.link(label: m[1], href: m[2]))
                }
            }
            last = whole.location + whole.length
        }
        if last < ns.length {
            out.append(
                .text(
                    ns.substring(
                        with: NSRange(
                            location: last, length: ns.length - last))))
        }
        return out
    }
}
