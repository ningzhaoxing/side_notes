import AppKit
import SideNotesCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do {
            let store = try PlanStore()
            let coordinator = AppCoordinator(store: store)
            self.coordinator = coordinator
            coordinator.start()
        } catch {
            NSAlert(error: error).runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

