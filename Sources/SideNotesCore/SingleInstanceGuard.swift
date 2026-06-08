import Darwin
import Foundation

public final class SingleInstanceGuard {
    public enum Error: Swift.Error, Equatable, CustomStringConvertible {
        case alreadyRunning
        case openFailed(Int32)
        case lockFailed(Int32)

        public var description: String {
            switch self {
            case .alreadyRunning:
                return "SideNotes is already running."
            case .openFailed(let code):
                return "Could not open SideNotes instance lock: errno \(code)."
            case .lockFailed(let code):
                return "Could not lock SideNotes instance file: errno \(code)."
            }
        }
    }

    private let fileDescriptor: Int32
    private let lockPath: String
    private static let activePathsLock = NSLock()
    nonisolated(unsafe) private static var activePaths: Set<String> = []

    public init(lockURL: URL = SingleInstanceGuard.defaultLockURL()) throws {
        let lockPath = lockURL.standardizedFileURL.path
        try FileManager.default.createDirectory(
            at: lockURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try Self.reserveActivePath(lockPath)

        let descriptor = Darwin.open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            Self.releaseActivePath(lockPath)
            throw Error.openFailed(errno)
        }

        if Self.setLock(type: F_WRLCK, descriptor: descriptor) != 0 {
            let errorCode = errno
            Darwin.close(descriptor)
            Self.releaseActivePath(lockPath)
            if errorCode == EACCES || errorCode == EAGAIN || errorCode == EWOULDBLOCK {
                throw Error.alreadyRunning
            }
            throw Error.lockFailed(errorCode)
        }

        fileDescriptor = descriptor
        self.lockPath = lockPath
    }

    deinit {
        _ = Self.setLock(type: F_UNLCK, descriptor: fileDescriptor)
        Darwin.close(fileDescriptor)
        Self.releaseActivePath(lockPath)
    }

    public static func defaultLockURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("SideNotes", isDirectory: true)
            .appendingPathComponent("SideNotes.lock")
    }

    private static func reserveActivePath(_ path: String) throws {
        activePathsLock.lock()
        defer { activePathsLock.unlock() }
        if activePaths.contains(path) {
            throw Error.alreadyRunning
        }
        activePaths.insert(path)
    }

    private static func releaseActivePath(_ path: String) {
        activePathsLock.lock()
        activePaths.remove(path)
        activePathsLock.unlock()
    }

    private static func setLock(type: Int32, descriptor: Int32) -> Int32 {
        var lock = Darwin.flock()
        lock.l_type = Int16(type)
        lock.l_whence = Int16(SEEK_SET)
        lock.l_start = 0
        lock.l_len = 0
        return Darwin.fcntl(descriptor, F_SETLK, &lock)
    }
}
