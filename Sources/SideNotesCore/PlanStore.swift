import Foundation

public final class PlanStore {
    private let database: SQLiteDatabase
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(databaseURL: URL = PlanStore.defaultDatabaseURL()) throws {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        decoder.dateDecodingStrategy = .secondsSince1970
        database = try SQLiteDatabase(url: databaseURL)
        try migrate()
        try ensureCurrentPlan()
        try ensureSettings()
    }

    public static func defaultDatabaseURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["SIDE_NOTES_DATABASE_PATH"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("SideNotes", isDirectory: true)
            .appendingPathComponent("SideNotes.sqlite")
    }

    public func loadDailyPlan() throws -> DailyPlan {
        let planRows = try database.query(
            """
            SELECT id, planning_date, created_at, updated_at
            FROM daily_plan
            WHERE singleton = 1
            """
        ) { statement in
            (
                id: try sqliteText(statement, 0),
                planningDate: Date(timeIntervalSince1970: sqliteDouble(statement, 1)),
                createdAt: Date(timeIntervalSince1970: sqliteDouble(statement, 2)),
                updatedAt: Date(timeIntervalSince1970: sqliteDouble(statement, 3))
            )
        }

        guard let row = planRows.first else {
            throw SQLiteStoreError.missingValue("current daily plan")
        }

        let planID: UUID
        let updatedAt: Date
        if let existingID = UUID(uuidString: row.id) {
            planID = existingID
            updatedAt = row.updatedAt
        } else {
            planID = UUID()
            updatedAt = Date()
            try database.execute(
                "UPDATE daily_plan SET id = ?, updated_at = ? WHERE singleton = 1",
                [.text(planID.uuidString), .double(updatedAt.timeIntervalSince1970)]
            )
        }

        var plan = DailyPlan(
            id: planID,
            planningDate: row.planningDate,
            groups: [],
            createdAt: row.createdAt,
            updatedAt: updatedAt
        )
        plan.groups = try loadDailyGroups()
        return plan
    }

    public func addDailyGroup(title: String) throws -> DailyPlanGroup {
        let group = DailyPlanGroup(title: title, sortOrder: try nextSortOrder(table: "daily_groups", ownerColumn: nil, ownerID: nil))
        try database.transaction {
            try database.execute(
                """
                INSERT INTO daily_groups (id, title, sort_order)
                VALUES (?, ?, ?)
                """,
                [.text(group.id.uuidString), .text(group.title), .int(group.sortOrder)]
            )
            try touchDailyPlan()
        }
        return group
    }

    public func renameDailyGroup(id: UUID, title: String) throws {
        try database.transaction {
            try ensureRowExists(table: "daily_groups", id: id, description: "daily group")
            try database.execute(
                "UPDATE daily_groups SET title = ? WHERE id = ?",
                [.text(title), .text(id.uuidString)]
            )
            try touchDailyPlan()
        }
    }

    public func moveDailyGroup(id: UUID, toSortOrder sortOrder: Int) throws {
        try database.transaction {
            try reorder(table: "daily_groups", id: id, toSortOrder: sortOrder)
            try touchDailyPlan()
        }
    }

    public func deleteDailyGroup(id: UUID) throws {
        try database.transaction {
            try ensureRowExists(table: "daily_groups", id: id, description: "daily group")
            try database.execute(
                "DELETE FROM daily_groups WHERE id = ?",
                [.text(id.uuidString)]
            )
            try touchDailyPlan()
        }
    }

    public func addDailyTask(groupID: UUID, title: String) throws -> DailyTask {
        let task = DailyTask(
            title: title,
            sortOrder: try nextSortOrder(table: "daily_tasks", ownerColumn: "group_id", ownerID: groupID)
        )
        try database.transaction {
            try database.execute(
                """
                INSERT INTO daily_tasks (id, group_id, title, is_completed, sort_order, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    .text(task.id.uuidString),
                    .text(groupID.uuidString),
                    .text(task.title),
                    .int(task.isCompleted ? 1 : 0),
                    .int(task.sortOrder),
                    .double(task.createdAt.timeIntervalSince1970),
                    .double(task.updatedAt.timeIntervalSince1970)
                ]
            )
            try touchDailyPlan()
        }
        return task
    }

    public func renameDailyTask(id: UUID, title: String) throws {
        try database.transaction {
            try ensureRowExists(table: "daily_tasks", id: id, description: "daily task")
            try database.execute(
                "UPDATE daily_tasks SET title = ?, updated_at = ? WHERE id = ?",
                [.text(title), .double(Date().timeIntervalSince1970), .text(id.uuidString)]
            )
            try touchDailyPlan()
        }
    }

    public func moveDailyTask(id: UUID, toSortOrder sortOrder: Int) throws {
        try database.transaction {
            let groupRows = try database.query(
                "SELECT group_id FROM daily_tasks WHERE id = ?",
                [.text(id.uuidString)]
            ) { statement in
                try sqliteText(statement, 0)
            }
            guard let groupID = groupRows.first else {
                throw SQLiteStoreError.missingValue("daily task group")
            }
            try reorder(table: "daily_tasks", id: id, toSortOrder: sortOrder, ownerColumn: "group_id", ownerValue: groupID)
            try touchDailyPlan()
        }
    }

    public func deleteDailyTask(id: UUID) throws {
        try database.transaction {
            try ensureRowExists(table: "daily_tasks", id: id, description: "daily task")
            try database.execute(
                "DELETE FROM daily_tasks WHERE id = ?",
                [.text(id.uuidString)]
            )
            try touchDailyPlan()
        }
    }

    public func toggleTask(id: UUID) throws -> DailyTask {
        let rows = try database.query(
            """
            SELECT group_id, title, is_completed, sort_order, created_at, updated_at
            FROM daily_tasks
            WHERE id = ?
            """,
            [.text(id.uuidString)]
        ) { statement in
            (
                groupID: try UUID.from(sqliteText(statement, 0)),
                title: try sqliteText(statement, 1),
                isCompleted: sqliteInt(statement, 2) != 0,
                sortOrder: sqliteInt(statement, 3),
                createdAt: Date(timeIntervalSince1970: sqliteDouble(statement, 4)),
                updatedAt: Date(timeIntervalSince1970: sqliteDouble(statement, 5))
            )
        }
        guard let row = rows.first else {
            throw SQLiteStoreError.missingValue("task \(id)")
        }

        let updated = DailyTask(
            id: id,
            title: row.title,
            isCompleted: !row.isCompleted,
            sortOrder: row.sortOrder,
            createdAt: row.createdAt,
            updatedAt: Date()
        )

        try database.transaction {
            try database.execute(
                """
                UPDATE daily_tasks
                SET is_completed = ?, updated_at = ?
                WHERE id = ?
                """,
                [.int(updated.isCompleted ? 1 : 0), .double(updated.updatedAt.timeIntervalSince1970), .text(id.uuidString)]
            )
            try touchDailyPlan()
        }
        return updated
    }

    public func loadLongTermAreas() throws -> [LongTermArea] {
        let rows = try database.query(
            """
            SELECT id, title, sort_order, created_at, updated_at
            FROM long_term_areas
            ORDER BY sort_order ASC, created_at ASC
            """
        ) { statement in
            (
                id: try sqliteText(statement, 0),
                title: try sqliteText(statement, 1),
                sortOrder: sqliteInt(statement, 2),
                createdAt: Date(timeIntervalSince1970: sqliteDouble(statement, 3)),
                updatedAt: Date(timeIntervalSince1970: sqliteDouble(statement, 4))
            )
        }

        var areas = rows.compactMap { row -> LongTermArea? in
            guard let id = UUID(uuidString: row.id) else { return nil }
            return LongTermArea(
                id: id,
                title: row.title,
                sortOrder: row.sortOrder,
                items: [],
                createdAt: row.createdAt,
                updatedAt: row.updatedAt
            )
        }

        for index in areas.indices {
            areas[index].items = try loadLongTermItems(areaID: areas[index].id)
        }
        return areas
    }

    public func addLongTermArea(title: String) throws -> LongTermArea {
        let now = Date()
        let area = LongTermArea(
            title: title,
            sortOrder: try nextSortOrder(table: "long_term_areas", ownerColumn: nil, ownerID: nil),
            createdAt: now,
            updatedAt: now
        )
        try database.execute(
            """
            INSERT INTO long_term_areas (id, title, sort_order, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            [
                .text(area.id.uuidString),
                .text(area.title),
                .int(area.sortOrder),
                .double(area.createdAt.timeIntervalSince1970),
                .double(area.updatedAt.timeIntervalSince1970)
            ]
        )
        return area
    }

    public func renameLongTermArea(id: UUID, title: String) throws {
        try database.transaction {
            try ensureRowExists(table: "long_term_areas", id: id, description: "long-term area")
            try database.execute(
                "UPDATE long_term_areas SET title = ?, updated_at = ? WHERE id = ?",
                [.text(title), .double(Date().timeIntervalSince1970), .text(id.uuidString)]
            )
        }
    }

    public func moveLongTermArea(id: UUID, toSortOrder sortOrder: Int) throws {
        try database.transaction {
            try reorder(table: "long_term_areas", id: id, toSortOrder: sortOrder)
        }
    }

    public func deleteLongTermArea(id: UUID) throws {
        try database.transaction {
            try ensureRowExists(table: "long_term_areas", id: id, description: "long-term area")
            try database.execute(
                "DELETE FROM long_term_areas WHERE id = ?",
                [.text(id.uuidString)]
            )
        }
    }

    public func addLongTermItem(areaID: UUID, title: String) throws -> LongTermItem {
        let now = Date()
        let item = LongTermItem(
            title: title,
            sortOrder: try nextSortOrder(table: "long_term_items", ownerColumn: "area_id", ownerID: areaID),
            createdAt: now,
            updatedAt: now
        )
        try database.execute(
            """
            INSERT INTO long_term_items (id, area_id, title, sort_order, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [
                .text(item.id.uuidString),
                .text(areaID.uuidString),
                .text(item.title),
                .int(item.sortOrder),
                .double(item.createdAt.timeIntervalSince1970),
                .double(item.updatedAt.timeIntervalSince1970)
            ]
        )
        return item
    }

    public func renameLongTermItem(id: UUID, title: String) throws {
        try database.transaction {
            try ensureRowExists(table: "long_term_items", id: id, description: "long-term item")
            try database.execute(
                "UPDATE long_term_items SET title = ?, updated_at = ? WHERE id = ?",
                [.text(title), .double(Date().timeIntervalSince1970), .text(id.uuidString)]
            )
        }
    }

    public func moveLongTermItem(id: UUID, toSortOrder sortOrder: Int) throws {
        try database.transaction {
            let areaRows = try database.query(
                "SELECT area_id FROM long_term_items WHERE id = ?",
                [.text(id.uuidString)]
            ) { statement in
                try sqliteText(statement, 0)
            }
            guard let areaID = areaRows.first else {
                throw SQLiteStoreError.missingValue("long-term item area")
            }
            try reorder(table: "long_term_items", id: id, toSortOrder: sortOrder, ownerColumn: "area_id", ownerValue: areaID)
        }
    }

    public func deleteLongTermItem(id: UUID) throws {
        try database.transaction {
            try ensureRowExists(table: "long_term_items", id: id, description: "long-term item")
            try database.execute(
                "DELETE FROM long_term_items WHERE id = ?",
                [.text(id.uuidString)]
            )
        }
    }

    public func archiveCurrentPlan(now: Date = Date()) throws -> ArchiveDay {
        try database.transaction {
            let current = try loadDailyPlan()
            let existing = try loadArchives()
            let result = ArchiveService.archive(plan: current, existingArchives: existing, now: now)
            guard let archive = result.archives.last else {
                throw SQLiteStoreError.invalidValue("archive result missing new archive")
            }

            let snapshotData = try encoder.encode(archive.groupsSnapshot)
            guard let snapshot = String(data: snapshotData, encoding: .utf8) else {
                throw SQLiteStoreError.invalidValue("archive snapshot encoding")
            }

            try database.execute(
                """
                INSERT INTO archives (id, archive_date, source_planning_date, groups_snapshot, created_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                [
                    .text(archive.id.uuidString),
                    .double(archive.archiveDate.timeIntervalSince1970),
                    .double(archive.sourcePlanningDate.timeIntervalSince1970),
                    .text(snapshot),
                    .double(archive.createdAt.timeIntervalSince1970)
                ]
            )
            try database.execute("DELETE FROM daily_tasks")
            try database.execute("DELETE FROM daily_groups")
            try database.execute(
                """
                UPDATE daily_plan
                SET id = ?, planning_date = ?, created_at = ?, updated_at = ?
                WHERE singleton = 1
                """,
                [
                    .text(result.current.id.uuidString),
                    .double(result.current.planningDate.timeIntervalSince1970),
                    .double(result.current.createdAt.timeIntervalSince1970),
                    .double(result.current.updatedAt.timeIntervalSince1970)
                ]
            )
            var settings = try loadSettings()
            settings.lastArchiveDate = now
            try saveSettings(settings)
            return archive
        }
    }

    public func loadArchives() throws -> [ArchiveDay] {
        let rows = try database.query(
            """
            SELECT id, archive_date, source_planning_date, groups_snapshot, created_at
            FROM archives
            ORDER BY archive_date ASC, created_at ASC
            """
        ) { statement in
            (
                id: try sqliteText(statement, 0),
                archiveDate: sqliteDouble(statement, 1),
                sourcePlanningDate: sqliteDouble(statement, 2),
                groupsSnapshot: try sqliteText(statement, 3),
                createdAt: sqliteDouble(statement, 4)
            )
        }

        return rows.compactMap { row in
            guard
                let id = UUID(uuidString: row.id),
                let snapshotData = row.groupsSnapshot.data(using: .utf8),
                let groups = try? decoder.decode([DailyPlanGroup].self, from: snapshotData)
            else {
                return nil
            }
            return ArchiveDay(
                id: id,
                archiveDate: Date(timeIntervalSince1970: row.archiveDate),
                sourcePlanningDate: Date(timeIntervalSince1970: row.sourcePlanningDate),
                groupsSnapshot: groups,
                createdAt: Date(timeIntervalSince1970: row.createdAt)
            )
        }
    }

    public func searchArchives(query: String) throws -> [ArchiveDay] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else {
            return try loadArchives()
        }
        return try loadArchives().filter { archive in
            archive.groupsSnapshot.contains { group in
                group.title.lowercased().contains(needle)
                    || group.tasks.contains { $0.title.lowercased().contains(needle) }
            }
        }
    }

    public func loadSettings() throws -> AppSettings {
        let rows = try database.query(
            "SELECT value FROM settings WHERE key = 'app'",
            []
        ) { statement in
            try sqliteText(statement, 0)
        }
        guard let json = rows.first, let data = json.data(using: .utf8) else {
            return AppSettings.defaults()
        }
        var settings: AppSettings
        do {
            settings = try decoder.decode(AppSettings.self, from: data)
        } catch {
            settings = AppSettings.defaults()
        }
        settings.validate()
        return settings
    }

    public func saveSettings(_ settings: AppSettings) throws {
        var validated = settings
        validated.validate()
        let data = try encoder.encode(validated)
        guard let json = String(data: data, encoding: .utf8) else {
            throw SQLiteStoreError.invalidValue("settings encoding")
        }
        try database.execute(
            """
            INSERT INTO settings (key, value)
            VALUES ('app', ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value
            """,
            [.text(json)]
        )
    }

    private func migrate() throws {
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS daily_plan (
                singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
                id TEXT NOT NULL,
                planning_date REAL NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            )
            """
        )
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS daily_groups (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                sort_order INTEGER NOT NULL
            )
            """
        )
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS daily_tasks (
                id TEXT PRIMARY KEY,
                group_id TEXT NOT NULL REFERENCES daily_groups(id) ON DELETE CASCADE,
                title TEXT NOT NULL,
                is_completed INTEGER NOT NULL,
                sort_order INTEGER NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            )
            """
        )
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS long_term_areas (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                sort_order INTEGER NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            )
            """
        )
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS long_term_items (
                id TEXT PRIMARY KEY,
                area_id TEXT NOT NULL REFERENCES long_term_areas(id) ON DELETE CASCADE,
                title TEXT NOT NULL,
                sort_order INTEGER NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            )
            """
        )
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS archives (
                id TEXT PRIMARY KEY,
                archive_date REAL NOT NULL,
                source_planning_date REAL NOT NULL,
                groups_snapshot TEXT NOT NULL,
                created_at REAL NOT NULL
            )
            """
        )
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
            """
        )
    }

    private func ensureCurrentPlan() throws {
        let count = try database.query("SELECT COUNT(*) FROM daily_plan") { statement in
            sqliteInt(statement, 0)
        }.first ?? 0
        guard count == 0 else {
            return
        }
        let plan = DailyPlan()
        try database.execute(
            """
            INSERT INTO daily_plan (singleton, id, planning_date, created_at, updated_at)
            VALUES (1, ?, ?, ?, ?)
            """,
            [
                .text(plan.id.uuidString),
                .double(plan.planningDate.timeIntervalSince1970),
                .double(plan.createdAt.timeIntervalSince1970),
                .double(plan.updatedAt.timeIntervalSince1970)
            ]
        )
    }

    private func ensureSettings() throws {
        if try database.query("SELECT COUNT(*) FROM settings WHERE key = 'app'", map: { sqliteInt($0, 0) }).first == 0 {
            try saveSettings(.defaults())
        }
    }

    private func loadDailyGroups() throws -> [DailyPlanGroup] {
        let rows = try database.query(
            """
            SELECT id, title, sort_order
            FROM daily_groups
            ORDER BY sort_order ASC
            """
        ) { statement in
            (
                id: try sqliteText(statement, 0),
                title: try sqliteText(statement, 1),
                sortOrder: sqliteInt(statement, 2)
            )
        }

        var groups = rows.compactMap { row -> DailyPlanGroup? in
            guard let id = UUID(uuidString: row.id) else { return nil }
            return DailyPlanGroup(
                id: id,
                title: row.title,
                sortOrder: row.sortOrder,
                tasks: []
            )
        }

        for index in groups.indices {
            groups[index].tasks = try loadDailyTasks(groupID: groups[index].id)
        }
        return groups
    }

    private func loadDailyTasks(groupID: UUID) throws -> [DailyTask] {
        let rows = try database.query(
            """
            SELECT id, title, is_completed, sort_order, created_at, updated_at
            FROM daily_tasks
            WHERE group_id = ?
            ORDER BY sort_order ASC, created_at ASC
            """,
            [.text(groupID.uuidString)]
        ) { statement in
            (
                id: try sqliteText(statement, 0),
                title: try sqliteText(statement, 1),
                isCompleted: sqliteInt(statement, 2) != 0,
                sortOrder: sqliteInt(statement, 3),
                createdAt: Date(timeIntervalSince1970: sqliteDouble(statement, 4)),
                updatedAt: Date(timeIntervalSince1970: sqliteDouble(statement, 5))
            )
        }

        return rows.compactMap { row in
            guard let id = UUID(uuidString: row.id) else { return nil }
            return DailyTask(
                id: id,
                title: row.title,
                isCompleted: row.isCompleted,
                sortOrder: row.sortOrder,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt
            )
        }
    }

    private func loadLongTermItems(areaID: UUID) throws -> [LongTermItem] {
        let rows = try database.query(
            """
            SELECT id, title, sort_order, created_at, updated_at
            FROM long_term_items
            WHERE area_id = ?
            ORDER BY sort_order ASC, created_at ASC
            """,
            [.text(areaID.uuidString)]
        ) { statement in
            (
                id: try sqliteText(statement, 0),
                title: try sqliteText(statement, 1),
                sortOrder: sqliteInt(statement, 2),
                createdAt: Date(timeIntervalSince1970: sqliteDouble(statement, 3)),
                updatedAt: Date(timeIntervalSince1970: sqliteDouble(statement, 4))
            )
        }

        return rows.compactMap { row in
            guard let id = UUID(uuidString: row.id) else { return nil }
            return LongTermItem(
                id: id,
                title: row.title,
                sortOrder: row.sortOrder,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt
            )
        }
    }

    private func nextSortOrder(table: String, ownerColumn: String?, ownerID: UUID?) throws -> Int {
        if let ownerColumn, let ownerID {
            return try database.query(
                "SELECT COALESCE(MAX(sort_order) + 1, 0) FROM \(table) WHERE \(ownerColumn) = ?",
                [.text(ownerID.uuidString)]
            ) { statement in
                sqliteInt(statement, 0)
            }.first ?? 0
        }

        return try database.query(
            "SELECT COALESCE(MAX(sort_order) + 1, 0) FROM \(table)"
        ) { statement in
            sqliteInt(statement, 0)
        }.first ?? 0
    }

    private func reorder(
        table: String,
        id: UUID,
        toSortOrder targetSortOrder: Int,
        ownerColumn: String? = nil,
        ownerValue: String? = nil
    ) throws {
        let rows: [String]
        if let ownerColumn, let ownerValue {
            rows = try database.query(
                "SELECT id FROM \(table) WHERE \(ownerColumn) = ? ORDER BY sort_order ASC",
                [.text(ownerValue)]
            ) { statement in
                try sqliteText(statement, 0)
            }
        } else {
            rows = try database.query(
                "SELECT id FROM \(table) ORDER BY sort_order ASC"
            ) { statement in
                try sqliteText(statement, 0)
            }
        }

        let idString = id.uuidString
        guard rows.contains(idString) else {
            throw SQLiteStoreError.missingValue("\(table) row \(idString)")
        }

        var ordered = rows.filter { $0 != idString }
        let insertionIndex = max(0, min(targetSortOrder, ordered.count))
        ordered.insert(idString, at: insertionIndex)

        for (index, rowID) in ordered.enumerated() {
            try database.execute(
                "UPDATE \(table) SET sort_order = ? WHERE id = ?",
                [.int(index), .text(rowID)]
            )
        }
    }

    private func ensureRowExists(table: String, id: UUID, description: String) throws {
        let count = try database.query(
            "SELECT COUNT(*) FROM \(table) WHERE id = ?",
            [.text(id.uuidString)]
        ) { statement in
            sqliteInt(statement, 0)
        }.first ?? 0
        guard count > 0 else {
            throw SQLiteStoreError.missingValue("\(description) \(id)")
        }
    }

    private func touchDailyPlan() throws {
        try database.execute(
            "UPDATE daily_plan SET updated_at = ? WHERE singleton = 1",
            [.double(Date().timeIntervalSince1970)]
        )
    }
}

private extension UUID {
    static func from(_ value: String) throws -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            throw SQLiteStoreError.invalidValue("invalid UUID \(value)")
        }
        return uuid
    }
}
