import Foundation
import SQLite3

enum SQLiteStoreError: Error, CustomStringConvertible, LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed(String)
    case missingValue(String)
    case invalidValue(String)

    var description: String {
        switch self {
        case .openFailed(let message): "open failed: \(message)"
        case .prepareFailed(let message): "prepare failed: \(message)"
        case .stepFailed(let message): "step failed: \(message)"
        case .bindFailed(let message): "bind failed: \(message)"
        case .missingValue(let message): "missing value: \(message)"
        case .invalidValue(let message): "invalid value: \(message)"
        }
    }

    var errorDescription: String? {
        description
    }
}

enum SQLiteValue {
    case text(String)
    case int(Int)
    case double(Double)
    case null
}

final class SQLiteDatabase {
    private let handle: OpaquePointer

    init(url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var db: OpaquePointer?
        let result = sqlite3_open(url.path, &db)
        guard result == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw SQLiteStoreError.openFailed(message)
        }
        handle = db
        try execute("PRAGMA foreign_keys = ON")
    }

    deinit {
        sqlite3_close(handle)
    }

    func execute(_ sql: String, _ bindings: [SQLiteValue] = []) throws {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE else {
            throw SQLiteStoreError.stepFailed(errorMessage)
        }
    }

    func query<T>(_ sql: String, _ bindings: [SQLiteValue] = [], map: (OpaquePointer) throws -> T) throws -> [T] {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)

        var rows: [T] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                rows.append(try map(statement))
            } else if result == SQLITE_DONE {
                return rows
            } else {
                throw SQLiteStoreError.stepFailed(errorMessage)
            }
        }
    }

    func transaction<T>(_ work: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let value = try work()
            try execute("COMMIT")
            return value
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard result == SQLITE_OK, let statement else {
            throw SQLiteStoreError.prepareFailed(errorMessage)
        }
        return statement
    }

    private func bind(_ values: [SQLiteValue], to statement: OpaquePointer) throws {
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            let result: Int32
            switch value {
            case .text(let text):
                result = sqlite3_bind_text(statement, position, text, -1, sqliteTransient)
            case .int(let int):
                result = sqlite3_bind_int64(statement, position, sqlite3_int64(int))
            case .double(let double):
                result = sqlite3_bind_double(statement, position, double)
            case .null:
                result = sqlite3_bind_null(statement, position)
            }
            guard result == SQLITE_OK else {
                throw SQLiteStoreError.bindFailed(errorMessage)
            }
        }
    }

    private var errorMessage: String {
        String(cString: sqlite3_errmsg(handle))
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

func sqliteText(_ statement: OpaquePointer, _ index: Int32) throws -> String {
    guard let pointer = sqlite3_column_text(statement, index) else {
        throw SQLiteStoreError.missingValue("column \(index)")
    }
    return String(cString: pointer)
}

func sqliteOptionalText(_ statement: OpaquePointer, _ index: Int32) -> String? {
    guard let pointer = sqlite3_column_text(statement, index) else {
        return nil
    }
    return String(cString: pointer)
}

func sqliteDouble(_ statement: OpaquePointer, _ index: Int32) -> Double {
    sqlite3_column_double(statement, index)
}

func sqliteInt(_ statement: OpaquePointer, _ index: Int32) -> Int {
    Int(sqlite3_column_int64(statement, index))
}
