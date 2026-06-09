import AppKit

enum StaleInstanceTerminator {
    private static let bundleIdentifier = "com.ningzhaoxing.sidenotes"
    private static let appName = "SideNotes"

    static func terminateAfterOwningLock() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let staleApps = NSWorkspace.shared.runningApplications.filter { app in
            guard app.processIdentifier != currentPID else { return false }
            return app.bundleIdentifier == bundleIdentifier || app.localizedName == appName
        }

        guard !staleApps.isEmpty else { return }

        for app in staleApps {
            app.terminate()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            for app in staleApps where !app.isTerminated {
                app.forceTerminate()
            }
        }
    }
}
