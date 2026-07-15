import Foundation

/// Watches a sync folder for changes to its entries — a note file appearing,
/// disappearing, or being renamed by the file-sync daemon (Dropbox, iCloud,
/// Syncthing) — and fires `onChange` (debounced, on the main queue) so the
/// store can re-read and surface notes written on other devices.
///
/// This is a directory-level vnode watch: it catches notes being *added* or
/// *removed*, which is what "new notes show up automatically" needs. Edits to
/// an already-present file's bytes don't alter the directory, so those are
/// picked up on the next add/remove or manual sync.
final class FolderWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private var pending: DispatchWorkItem?
    private let onChange: () -> Void
    private let debounce: TimeInterval

    init?(url: URL, debounce: TimeInterval = 0.4, onChange: @escaping () -> Void) {
        self.onChange = onChange
        self.debounce = debounce

        fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return nil }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: DispatchQueue.global(qos: .utility))
        src.setEventHandler { [weak self] in self?.coalesce() }
        src.setCancelHandler { [fd] in if fd >= 0 { close(fd) } }
        src.resume()
        source = src
    }

    private func coalesce() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: work)
    }

    func stop() {
        pending?.cancel()
        pending = nil
        source?.cancel()
        source = nil
        fd = -1
    }

    deinit { stop() }
}
