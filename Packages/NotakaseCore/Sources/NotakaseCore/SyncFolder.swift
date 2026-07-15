import Foundation
import SwiftUI

/// Owns the user-selected "sync folder" — the directory Notakase points at to
/// read/write markdown. This pass persists the *choice* (as a security-scoped
/// bookmark) and surfaces it in the UI; actually loading `.md` files from it is
/// a follow-up. Mirrors the bookmark approach used by todarchy-ios.
@MainActor
public final class SyncFolder: ObservableObject {
    @Published public private(set) var folderURL: URL?

    private let bookmarkKey = "notakase.syncFolderBookmark"

    public init() {
        folderURL = Self.resolveBookmark(key: bookmarkKey)
    }

    public var isSet: Bool { folderURL != nil }

    public var folderName: String? { folderURL?.lastPathComponent }

    /// A readable path for display (`~`-abbreviated on the home directory).
    public var displayPath: String {
        guard let url = folderURL else { return "No folder selected" }
        let path = url.path(percentEncoded: false)
        let home = NSHomeDirectory()
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~/" + path.dropFirst(home.count + 1)
        }
        return path
    }

    /// Persist a newly-picked folder.
    public func setFolder(_ url: URL) {
        do {
            _ = url.startAccessingSecurityScopedResource()
            let data = try url.bookmarkData(
                options: Self.creationOptions,
                includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            folderURL = url
        } catch {
            #if DEBUG
            print("Notakase: couldn't save sync folder: \(error)")
            #endif
        }
    }

    /// Forget the current folder.
    public func clearFolder() {
        folderURL?.stopAccessingSecurityScopedResource()
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        folderURL = nil
    }

    // MARK: - Bookmark helpers

    private static func resolveBookmark(key: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        var stale = false
        guard
            let url = try? URL(
                resolvingBookmarkData: data, options: resolutionOptions,
                relativeTo: nil, bookmarkDataIsStale: &stale)
        else { return nil }
        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    // The macOS app is not sandboxed, so plain bookmarks suffice. If the app
    // is ever sandboxed, switch macOS to `.withSecurityScope` and add the
    // `com.apple.security.files.user-selected.read-write` entitlement.
    private static var creationOptions: URL.BookmarkCreationOptions { [] }

    private static var resolutionOptions: URL.BookmarkResolutionOptions { [] }
}
