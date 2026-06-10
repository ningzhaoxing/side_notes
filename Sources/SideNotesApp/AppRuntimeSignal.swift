import Foundation

enum AppRuntimeSignal {
    static let showCardNotificationName = Notification.Name("com.ningzhaoxing.sidenotes.showCard")
    static let quitNotificationName = Notification.Name("com.ningzhaoxing.sidenotes.quit")

    static func writeQuitRequest() {
        let url = quitRequestURL()
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try "\(Date().timeIntervalSince1970)\n".write(to: url, atomically: true, encoding: .utf8)
        } catch {
            fputs("Could not write SideNotes quit request: \(error)\n", stderr)
        }
    }

    static func hasPendingQuitRequest(after minimumTimestamp: TimeInterval, maxAge: TimeInterval = 5.0) -> Bool {
        let url = quitRequestURL()
        guard
            let rawTimestamp = try? String(contentsOf: url, encoding: .utf8),
            let timestamp = TimeInterval(rawTimestamp.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            return false
        }
        guard timestamp > minimumTimestamp else {
            return false
        }
        return Date().timeIntervalSince1970 - timestamp <= maxAge
    }

    static func clearQuitRequest() {
        try? FileManager.default.removeItem(at: quitRequestURL())
    }

    private static func quitRequestURL() -> URL {
        URL(fileURLWithPath: "/private/tmp")
            .appendingPathComponent("com.ningzhaoxing.sidenotes.\(NSUserName()).quit-request")
    }
}
