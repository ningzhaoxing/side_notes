import AppKit
import Darwin
import SideNotesCore

if ProcessInfo.processInfo.environment["SIDE_NOTES_REQUEST_QUIT_EXISTING"] == "1" {
    AppRuntimeSignal.writeQuitRequest()
    DistributedNotificationCenter.default().post(
        name: AppCoordinator.quitNotificationName,
        object: nil
    )
    Thread.sleep(forTimeInterval: 1.0)
    AppRuntimeSignal.clearQuitRequest()
    exit(0)
}

let preflightInstanceGuard: SingleInstanceGuard?
if ProcessInfo.processInfo.environment["SIDE_NOTES_ALLOW_MULTIPLE_INSTANCES"] == "1" {
    preflightInstanceGuard = nil
} else {
    do {
        preflightInstanceGuard = try SingleInstanceGuard()
    } catch SingleInstanceGuard.Error.alreadyRunning {
        AppRuntimeSignal.writeShowRequest()
        DistributedNotificationCenter.default().post(
            name: AppCoordinator.showCardNotificationName,
            object: nil
        )
        exit(0)
    } catch {
        fputs("SideNotes startup error: \(error)\n", stderr)
        exit(1)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var instanceGuard: SingleInstanceGuard?
    private var didStart = false

    init(instanceGuard: SingleInstanceGuard?) {
        self.instanceGuard = instanceGuard
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !didStart else { return }
        didStart = true
        NSApp.setActivationPolicy(.accessory)
        do {
            if instanceGuard != nil {
                StaleInstanceTerminator.terminateAfterOwningLock()
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        coordinator?.showCard()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

let app = NSApplication.shared
let delegate = AppDelegate(instanceGuard: preflightInstanceGuard)
app.delegate = delegate
app.finishLaunching()
delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification, object: app))
withExtendedLifetime(delegate) {
    app.run()
}
