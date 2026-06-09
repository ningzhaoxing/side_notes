import AppKit
import Darwin
import SideNotesCore

if ProcessInfo.processInfo.environment["SIDE_NOTES_REQUEST_QUIT_EXISTING"] == "1" {
    DistributedNotificationCenter.default().post(
        name: AppCoordinator.quitNotificationName,
        object: nil
    )
    exit(0)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var instanceGuard: SingleInstanceGuard?
    private var didStart = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !didStart else { return }
        didStart = true
        NSApp.setActivationPolicy(.accessory)
        do {
            if ProcessInfo.processInfo.environment["SIDE_NOTES_ALLOW_MULTIPLE_INSTANCES"] != "1" {
                do {
                    instanceGuard = try SingleInstanceGuard()
                } catch SingleInstanceGuard.Error.alreadyRunning {
                    DistributedNotificationCenter.default().post(
                        name: AppCoordinator.showCardNotificationName,
                        object: nil
                    )
                    NSApp.terminate(nil)
                    return
                }
            }

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
