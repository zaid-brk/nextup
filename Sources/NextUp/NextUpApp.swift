import AppKit
import SwiftUI

@main
struct NextUpApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
                .frame(minWidth: 980, minHeight: 720)
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 1180, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") { NotificationCenter.default.post(name: .newTask, object: nil) }
                    .keyboardShortcut("n")
            }
            CommandGroup(after: .saveItem) {
                Button("Export Backup…") { store.exportBackup() }.disabled(store.loadFailed)
                Button("Show Data Folder") { store.showDataFolder() }
            }
        }
    }
}

extension Notification.Name { static let newTask = Notification.Name("NextUp.newTask") }
