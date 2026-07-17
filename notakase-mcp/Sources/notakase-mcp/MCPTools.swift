import Foundation
import NotakaseCore

struct MCPTool {
    let name: String
    let description: String
    let inputSchema: [String: Any]
    var descriptor: [String: Any] {
        ["name": name, "description": description, "inputSchema": inputSchema]
    }
}

enum MCPTools {
    static let all: [MCPTool] = [
        listNotesTool, getNoteTool, addNoteTool,
        appendNoteTool, updateNoteTool, moveNoteTool, deleteNoteTool,
    ]

    static func call(params: [String: Any], config: MCPConfig) throws -> Any {
        guard let name = params["name"] as? String else {
            throw MCPError(code: -32602, message: "tools/call requires `name`")
        }
        let args = (params["arguments"] as? [String: Any]) ?? [:]

        let text: String
        switch name {
        case "list_notes": text = try handleList(args: args, config: config)
        case "get_note": text = try handleGet(args: args, config: config)
        case "add_note":
            try requireWritable(config)
            text = try handleAdd(args: args, config: config)
        case "append_to_note":
            try requireWritable(config)
            text = try handleAppend(args: args, config: config)
        case "update_note":
            try requireWritable(config)
            text = try handleUpdate(args: args, config: config)
        case "move_note":
            try requireWritable(config)
            text = try handleMove(args: args, config: config)
        case "delete_note":
            try requireWritable(config)
            text = try handleDelete(args: args, config: config)
        default:
            throw MCPError(code: -32601, message: "Unknown tool: \(name)")
        }
        return ["content": [["type": "text", "text": text]]]
    }

    /// Load the note with `id` or throw a friendly error.
    private static func loadNote(_ id: String, _ config: MCPConfig) throws -> Note {
        let loaded = try AutomergeVault.load(from: config.folderURL)
        guard let n = loaded.notes.first(where: { $0.id == id }) else {
            throw MCPError(code: -32000, message: "No note with id \(id)")
        }
        return n
    }

    private static func requireWritable(_ config: MCPConfig) throws {
        if config.readOnly {
            throw MCPError(
                code: -32000,
                message: "Server is read-only. Unset NOTAKASE_MCP_READ_ONLY to enable writes.")
        }
    }

    // MARK: - Handlers

    private static func handleList(args: [String: Any], config: MCPConfig) throws -> String {
        let loaded = try AutomergeVault.load(from: config.folderURL)
        var notes = loaded.notes
        if let folder = (args["folder"] as? String), !folder.isEmpty {
            let prefix = folder.split(separator: "/").map(String.init)
            notes = notes.filter { Array($0.dir.prefix(prefix.count)) == prefix }
        }
        if notes.isEmpty { return "No notes found." }
        let lines = notes.map { n -> String in
            let path = (n.dir + [n.fileName]).joined(separator: "/")
            return "\(n.id)  \(path)  — \(n.title)"
        }
        return "\(notes.count) note(s):\n" + lines.joined(separator: "\n")
    }

    private static func handleGet(args: [String: Any], config: MCPConfig) throws -> String {
        guard let id = args["id"] as? String else {
            throw MCPError(code: -32602, message: "get_note requires `id`")
        }
        let loaded = try AutomergeVault.load(from: config.folderURL)
        guard let n = loaded.notes.first(where: { $0.id == id }) else {
            throw MCPError(code: -32000, message: "No note with id \(id)")
        }
        let path = (n.dir + [n.fileName]).joined(separator: "/")
        return "# \(n.title)\npath: \(path)\nid: \(n.id)\n\n\(n.body)"
    }

    private static func handleAdd(args: [String: Any], config: MCPConfig) throws -> String {
        guard let title = (args["title"] as? String), !title.isEmpty else {
            throw MCPError(code: -32602, message: "add_note requires a non-empty `title`")
        }
        let folder = (args["folder"] as? String) ?? ""
        let dir = folder.split(separator: "/").map(String.init)
        var body = (args["body"] as? String) ?? ""
        // Ensure the title is the note's H1 so it survives the round-trip
        // (the app derives a note's title from the first heading).
        if !body.hasPrefix("# ") {
            body = "# \(title)\n\n" + body
        }
        let note = Note(
            id: AutomergeVault.newID(), dir: dir, title: title,
            updated: "just now", body: body)
        try AutomergeVault.write(note: note, to: config.folderURL)
        let path = (note.dir + [note.fileName]).joined(separator: "/")
        return "Created note \(note.id) at \(path)"
    }

    private static func handleAppend(args: [String: Any], config: MCPConfig) throws -> String {
        guard let id = args["id"] as? String else {
            throw MCPError(code: -32602, message: "append_to_note requires `id`")
        }
        guard let text = args["text"] as? String, !text.isEmpty else {
            throw MCPError(code: -32602, message: "append_to_note requires non-empty `text`")
        }
        var note = try loadNote(id, config)
        // Separate the appended text from existing content with a blank line.
        let sep = note.body.hasSuffix("\n") ? "\n" : "\n\n"
        note.body += sep + text
        try AutomergeVault.write(note: note, to: config.folderURL)
        return "Appended to \(id)."
    }

    private static func handleUpdate(args: [String: Any], config: MCPConfig) throws -> String {
        guard let id = args["id"] as? String else {
            throw MCPError(code: -32602, message: "update_note requires `id`")
        }
        guard let body = args["body"] as? String else {
            throw MCPError(code: -32602, message: "update_note requires `body`")
        }
        var note = try loadNote(id, config)
        note.body = body
        try AutomergeVault.write(note: note, to: config.folderURL)
        return "Replaced body of \(id)."
    }

    private static func handleMove(args: [String: Any], config: MCPConfig) throws -> String {
        guard let id = args["id"] as? String else {
            throw MCPError(code: -32602, message: "move_note requires `id`")
        }
        let folder = (args["folder"] as? String) ?? ""
        let dir = folder.split(separator: "/").map(String.init)
        let note = try loadNote(id, config)
        try AutomergeVault.move(
            noteID: id, to: dir, fileName: note.fileName, in: config.folderURL)
        let dest = dir.isEmpty ? "the top level" : folder
        return "Moved \(id) to \(dest)."
    }

    private static func handleDelete(args: [String: Any], config: MCPConfig) throws -> String {
        guard let id = args["id"] as? String else {
            throw MCPError(code: -32602, message: "delete_note requires `id`")
        }
        _ = try loadNote(id, config)  // 404 if missing
        try AutomergeVault.delete(noteID: id, in: config.folderURL)
        return "Deleted \(id) (tombstoned; the delete syncs to other devices)."
    }

    // MARK: - Descriptors

    private static let listNotesTool = MCPTool(
        name: "list_notes",
        description: "List notakase notes (id, path, title). Optionally filter to a folder.",
        inputSchema: [
            "type": "object",
            "properties": [
                "folder": [
                    "type": "string",
                    "description":
                        "Optional folder path (e.g. \"Reference\" or \"Projects/client\") to filter by.",
                ]
            ],
        ])

    private static let getNoteTool = MCPTool(
        name: "get_note",
        description: "Fetch a note's full markdown body by id.",
        inputSchema: [
            "type": "object",
            "properties": ["id": ["type": "string", "description": "Note id."]],
            "required": ["id"],
        ])

    private static let addNoteTool = MCPTool(
        name: "add_note",
        description: """
            Create a new notakase note. Returns the new note's id and path. The \
            note syncs to all the user's devices via the shared folder.
            """,
        inputSchema: [
            "type": "object",
            "properties": [
                "title": ["type": "string", "description": "Note title (becomes the H1)."],
                "folder": [
                    "type": "string",
                    "default": "",
                    "description":
                        "Folder path (e.g. \"Reference\" or \"Projects/client/2026\"). Empty = top level.",
                ],
                "body": [
                    "type": "string",
                    "default": "",
                    "description": "Optional markdown body (below the title).",
                ],
            ],
            "required": ["title"],
        ])

    private static let appendNoteTool = MCPTool(
        name: "append_to_note",
        description: "Append markdown text to the end of a note's body.",
        inputSchema: [
            "type": "object",
            "properties": [
                "id": ["type": "string", "description": "Note id."],
                "text": ["type": "string", "description": "Markdown to append."],
            ],
            "required": ["id", "text"],
        ])

    private static let updateNoteTool = MCPTool(
        name: "update_note",
        description:
            "Replace a note's entire markdown body. The first `# heading` becomes its title.",
        inputSchema: [
            "type": "object",
            "properties": [
                "id": ["type": "string", "description": "Note id."],
                "body": ["type": "string", "description": "New full markdown body."],
            ],
            "required": ["id", "body"],
        ])

    private static let moveNoteTool = MCPTool(
        name: "move_note",
        description: "Move a note to a different folder (empty folder = top level).",
        inputSchema: [
            "type": "object",
            "properties": [
                "id": ["type": "string", "description": "Note id."],
                "folder": [
                    "type": "string",
                    "default": "",
                    "description": "Destination folder path, e.g. \"Projects/client\".",
                ],
            ],
            "required": ["id"],
        ])

    private static let deleteNoteTool = MCPTool(
        name: "delete_note",
        description:
            "Delete a note (tombstoned so the deletion propagates to other devices).",
        inputSchema: [
            "type": "object",
            "properties": ["id": ["type": "string", "description": "Note id."]],
            "required": ["id"],
        ])
}
