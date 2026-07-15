import NotakaseCore
import SwiftUI

@main
struct NotakaseApp: App {
    @StateObject private var store = NotakaseStore()
    @StateObject private var syncFolder = SyncFolder()
    @StateObject private var todokase = TodokaseTasks()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .environmentObject(syncFolder)
                .environmentObject(todokase)
                .frame(minWidth: 900, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView(store: store, syncFolder: syncFolder, todokase: todokase)
        }
    }
}
