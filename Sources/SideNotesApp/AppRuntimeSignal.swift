import Foundation

enum AppRuntimeSignal {
    static let showCardNotificationName = Notification.Name("com.ningzhaoxing.sidenotes.showCard")
    static let quitNotificationName = Notification.Name("com.ningzhaoxing.sidenotes.quit")

    static func writeShowRequest() {
        writeRequest(to: showRequestURL(), description: "show")
    }

    static func writeQuitRequest() {
        writeRequest(to: quitRequestURL(), description: "quit")
    }

    static func consumeShowRequest(after minimumTimestamp: TimeInterval, maxAge: TimeInterval = 5.0) -> Bool {
        let url = showRequestURL()
        guard hasPendingRequest(at: url, after: minimumTimestamp, maxAge: maxAge) else {
            return false
        }
        try? FileManager.default.removeItem(at: url)
        return true
    }

    static func hasPendingQuitRequest(after minimumTimestamp: TimeInterval, maxAge: TimeInterval = 5.0) -> Bool {
        hasPendingRequest(at: quitRequestURL(), after: minimumTimestamp, maxAge: maxAge)
    }

    static func clearQuitRequest() {
        try? FileManager.default.removeItem(at: quitRequestURL())
    }

    private static func writeRequest(to url: URL, description: String) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try "\(Date().timeIntervalSince1970)\n".write(to: url, atomically: true, encoding: .utf8)
        } catch {
            fputs("Could not write SideNotes \(description) request: \(error)\n", stderr)
        }
    }

    private static func hasPendingRequest(at url: URL, after minimumTimestamp: TimeInterval, maxAge: TimeInterval) -> Bool {
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

    private static func showRequestURL() -> URL {
        runtimeRequestURL(named: "show-request")
    }

    private static func quitRequestURL() -> URL {
        runtimeRequestURL(named: "quit-request")
    }

    private static func runtimeRequestURL(named name: String) -> URL {
        URL(fileURLWithPath: "/private/tmp")
            .appendingPathComponent("com.ningzhaoxing.sidenotes.\(NSUserName()).\(name)")
    }
}
