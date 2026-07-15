import SwiftUI

/// The parsed configuration of a ```todokase fenced block.
///
///     ```todokase
///     project: notakase
///     status: open
///     ```
///
/// `status` defaults to `open`; a bare first line is treated as the project
/// name so `​```todokase\nnotakase​```` works too.
public struct TodokaseEmbed: Equatable {
    public var project: String?
    public var status: TodokaseStatus

    public static func parse(_ text: String) -> TodokaseEmbed {
        var project: String?
        var status: TodokaseStatus = .open
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if let colon = line.firstIndex(of: ":") {
                let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                let value = line[line.index(after: colon)...]
                    .trimmingCharacters(in: .whitespaces)
                switch key {
                case "project", "list": project = value.isEmpty ? nil : value
                case "status": status = TodokaseStatus(rawValue: value.lowercased()) ?? .open
                default: break
                }
            } else if project == nil {
                // Bare line → project name shorthand.
                project = line
            }
        }
        return TodokaseEmbed(project: project, status: status)
    }
}

/// Renders a ```todokase fence as a live checklist pulled from the shared
/// task store. Read-only — tapping does nothing; it mirrors todokase.
public struct TodokaseBlockView: View {
    let config: String
    let theme: Theme
    let baseSize: CGFloat
    @EnvironmentObject var todokase: TodokaseTasks

    public init(config: String, theme: Theme, baseSize: CGFloat) {
        self.config = config
        self.theme = theme
        self.baseSize = baseSize
    }

    private var embed: TodokaseEmbed { TodokaseEmbed.parse(config) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            header
            content
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.sidebarColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(theme.borderColor, lineWidth: 1)
        )
        .padding(.bottom, 18)
        .onAppear { todokase.reload() }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Text("◫").foregroundStyle(theme.accentColor)
            Text("todokase")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(theme.faintColor)
            if let p = embed.project {
                Text("· \(p)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.faintColor)
            }
            Spacer(minLength: 0)
            if embed.project != nil && todokase.isSet {
                Text(embed.status.rawValue)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(theme.faintColor)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !todokase.isSet {
            hint("Set the todokase tasks file in Settings to embed tasks.")
        } else if let project = embed.project {
            let items = todokase.tasks(project: project, status: embed.status)
            if items.isEmpty {
                hint("No \(embed.status == .all ? "" : embed.status.rawValue + " ")tasks in “\(project)”.")
            } else {
                ForEach(items) { task in
                    HStack(alignment: .top, spacing: 10) {
                        Checkbox(done: task.done, theme: theme)
                            .padding(.top, 3)
                        Text(task.title)
                            .font(.system(size: baseSize * 0.92, design: .monospaced))
                            .strikethrough(task.done, color: theme.faintColor)
                            .foregroundStyle(task.done ? theme.faintColor : theme.fgColor)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        } else {
            hint("Specify a project, e.g. `project: notakase`.")
        }
    }

    private func hint(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(theme.faintColor)
            .fixedSize(horizontal: false, vertical: true)
    }
}
