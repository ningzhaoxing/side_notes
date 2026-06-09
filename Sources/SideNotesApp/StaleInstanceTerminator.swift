import AppKit

enum StaleInstanceTerminator {
    private static let bundleIdentifier = "com.ningzhaoxing.sidenotes"
    private static let appName = "SideNotes"
    private static let appBundleName = "SideNotes.app"

    static func terminateAfterOwningLock() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let staleApps = NSWorkspace.shared.runningApplications.filter { app in
            guard app.processIdentifier != currentPID else { return false }
            return isSideNotesInstance(app)
        }

        guard !staleApps.isEmpty else { return }

        for app in staleApps {
            if !app.terminate() {
                app.forceTerminate()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            for app in staleApps where !app.isTerminated {
                app.forceTerminate()
            }
        }
    }

    private static func isSideNotesInstance(_ app: NSRunningApplication) -> Bool {
        app.bundleIdentifier == bundleIdentifier
            || app.localizedName == appName
            || app.executableURL?.lastPathComponent == appName
            || app.bundleURL?.lastPathComponent == appBundleName
    }
}
