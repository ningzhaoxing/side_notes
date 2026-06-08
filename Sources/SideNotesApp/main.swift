import AppKit
import SideNotesCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var didStart = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !didStart else { return }
        didStart = true
        NSApp.setActivationPolicy(.accessory)
        do {
            let store = try PlanStore()
            let coordinator = AppCoordinator(store: store)
            self.coordinator = coordinator
            coordinator.start()
        } catch {
            fputs("SideNotes startup error: \(error)\n", stderr)
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
app.finishLaunching()
delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification, object: app))
withExtendedLifetime(delegate) {
    app.run()
}
