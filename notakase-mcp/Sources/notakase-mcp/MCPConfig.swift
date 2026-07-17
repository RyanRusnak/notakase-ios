import Foundation

/// Runtime configuration, sourced from environment variables the MCP client
/// (Claude Desktop / Claude Code) passes to the binary on launch.
struct MCPConfig {
    /// The notakase sync folder containing `note_<id>.automerge` files.
    let folderURL: URL
    /// When true, mutating tools refuse to run (read-only onboarding mode).
    let readOnly: Bool

    static func load() -> MCPConfig {
        let env = ProcessInfo.processInfo.environment
        let path = env["NOTAKASE_FOLDER"] ?? Self.defaultFolderPath()
        let readOnly = env["NOTAKASE_MCP_READ_ONLY"] == "1"
        return MCPConfig(
            folderURL: URL(fileURLWithPath: path, isDirectory: true),
            readOnly: readOnly)
    }

    /// Sensible default: the Dropbox sync folder the apps use. Override with
    /// `NOTAKASE_FOLDER` for a different location.
    private static func defaultFolderPath() -> String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/CloudStorage/Dropbox/notakase_sync")
            .path
    }
}
