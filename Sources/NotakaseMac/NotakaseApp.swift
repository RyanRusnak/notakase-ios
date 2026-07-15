import NotakaseCore
import SwiftUI

@main
struct NotakaseApp: App {
    @StateObject private var store = NotakaseStore()
    @StateObject private var syncFolder = SyncFolder()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .environmentObject(syncFolder)
                .frame(minWidth: 900, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView(store: store, syncFolder: syncFolder)
        }
    }
}
