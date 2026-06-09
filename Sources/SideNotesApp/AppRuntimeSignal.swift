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

    static func consumeQuitRequest() -> Bool {
        let url = quitRequestURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }
        try? FileManager.default.removeItem(at: url)
        return true
    }

    static func clearQuitRequest() {
        try? FileManager.default.removeItem(at: quitRequestURL())
    }

    private static func quitRequestURL() -> URL {
        URL(fileURLWithPath: "/private/tmp")
            .appendingPathComponent("com.ningzhaoxing.sidenotes.\(NSUserName()).quit-request")
    }
}
