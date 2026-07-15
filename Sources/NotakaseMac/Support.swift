import AppKit
import NotakaseCore
import SwiftUI

enum ViewMode: String, CaseIterable {
    case read, edit, publish
    var label: String {
        switch self {
        case .read: return "READ"
        case .edit: return "WRITE"
        case .publish: return "PUBLISH"
        }
    }
}

/// A single command-palette entry.
struct PaletteItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let hint: String
    let action: () -> Void
}

enum KeyCode {
    static let escape: UInt16 = 53
    static let ret: UInt16 = 36
    static let arrowDown: UInt16 = 125
    static let arrowUp: UInt16 = 126
}

/// Installs a window-local key-down monitor so the app can respond to modal
/// vim-style keys the way the desktop prototype did (document-level listener).
struct KeyCatcher: NSViewRepresentable {
    /// Return true if the event was handled (and should be swallowed).
    var onKey: (NSEvent) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { event in
            (context.coordinator.onKey?(event) ?? false) ? nil : event
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onKey = onKey
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let m = coordinator.monitor { NSEvent.removeMonitor(m) }
    }

    final class Coordinator {
        var monitor: Any?
        var onKey: ((NSEvent) -> Bool)?
    }
}
