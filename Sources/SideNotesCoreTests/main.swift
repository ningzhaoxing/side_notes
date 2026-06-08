import Foundation
import SideNotesCore

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TestFailure(description: message)
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
    if actual != expected {
        throw TestFailure(description: "\(message): expected \(expected), got \(actual)")
    }
}

func expectEqual(_ actual: Double, _ expected: Double, accuracy: Double, _ message: String) throws {
    if abs(actual - expected) > accuracy {
        throw TestFailure(description: "\(message): expected \(expected), got \(actual)")
    }
}

func testDefaultSettingsAreReadableAndUsable() throws {
    let settings = AppSettings.defaults()

    try expectEqual(settings.triggerSide, .right, "default trigger side")
    try expect(settings.isPinned, "default pinned state")
    try expectEqual(settings.visibleSide, .front, "default visible side")
    try expectEqual(settings.cardOpacity, 0.94, accuracy: 0.001, "default opacity")
    try expectEqual(settings.cardCornerRadius, 22, accuracy: 0.001, "default corner radius")
}

func testAppearanceSettingsClampToReadableRanges() throws {
    var settings = AppSettings.defaults()
    settings.cardOpacity = 0.1
    settings.cardCornerRadius = -20

    settings.validate()

    try expectEqual(settings.cardOpacity, 0.35, accuracy: 0.001, "minimum opacity clamp")
    try expectEqual(settings.cardCornerRadius, 4, accuracy: 0.001, "minimum corner radius clamp")

    settings.cardOpacity = 2
    settings.cardCornerRadius = 200

    settings.validate()

    try expectEqual(settings.cardOpacity, 1, accuracy: 0.001, "maximum opacity clamp")
    try expectEqual(settings.cardCornerRadius, 48, accuracy: 0.001, "maximum corner radius clamp")
}

func testWindowFrameOutsideScreensFallsBackToDefault() throws {
    var settings = AppSettings.defaults()
    settings.cardFrame = StoredRect(x: -9_000, y: -9_000, width: 320, height: 520)

    settings.validate(visibleFrames: [
        StoredRect(x: 0, y: 0, width: 1_440, height: 900)
    ])

    try expectEqual(settings.cardFrame.x, 1_088, accuracy: 0.001, "fallback x")
    try expectEqual(settings.cardFrame.y, 160, accuracy: 0.001, "fallback y")
    try expectEqual(settings.cardFrame.width, 320, accuracy: 0.001, "fallback width")
    try expectEqual(settings.cardFrame.height, 580, accuracy: 0.001, "fallback height")
}

func testCardSizeUpdatesClampToReadableRanges() throws {
    var settings = AppSettings.defaults()

    settings.setCardSize(width: 120, height: 220)
    try expectEqual(settings.cardFrame.width, 260, accuracy: 0.001, "minimum card width")
    try expectEqual(settings.cardFrame.height, 360, accuracy: 0.001, "minimum card height")

    settings.setCardSize(width: 900, height: 1_200)
    try expectEqual(settings.cardFrame.width, 720, accuracy: 0.001, "maximum card width")
    try expectEqual(settings.cardFrame.height, 900, accuracy: 0.001, "maximum card height")

    settings.setCardSize(width: 420, height: 640)
    try expectEqual(settings.cardFrame.width, 420, accuracy: 0.001, "custom card width")
    try expectEqual(settings.cardFrame.height, 640, accuracy: 0.001, "custom card height")
}

func testArchivePreservesGroupsTasksOrderAndCompletion() throws {
    let sourceDate = Date(timeIntervalSince1970: 1_700_000_000)
    let archiveDate = Date(timeIntervalSince1970: 1_700_086_400)
    let firstTask = DailyTask(title: "Draft launch plan", isCompleted: true, sortOrder: 0, createdAt: sourceDate, updatedAt: sourceDate)
    let secondTask = DailyTask(title: "Study English", isCompleted: false, sortOrder: 1, createdAt: sourceDate, updatedAt: sourceDate)
    let plan = DailyPlan(
        planningDate: sourceDate,
        groups: [
            DailyPlanGroup(title: "Work", sortOrder: 0, tasks: [firstTask]),
            DailyPlanGroup(title: "Learning", sortOrder: 1, tasks: [secondTask])
        ],
        createdAt: sourceDate,
        updatedAt: sourceDate
    )

    let result = ArchiveService.archive(plan: plan, existingArchives: [], now: archiveDate)

    try expect(result.current.groups.isEmpty, "current plan should be blank after archive")
    try expectEqual(result.archives.count, 1, "archive count")
    let archive = result.archives[0]
    try expectEqual(archive.archiveDate, archiveDate, "archive date")
    try expectEqual(archive.sourcePlanningDate, sourceDate, "source planning date")
    try expectEqual(archive.groupsSnapshot.map(\.title), ["Work", "Learning"], "group order")
    try expectEqual(archive.groupsSnapshot[0].tasks.map(\.title), ["Draft launch plan"], "first group task title")
    try expect(archive.groupsSnapshot[0].tasks[0].isCompleted, "completed task state")
    try expect(!archive.groupsSnapshot[1].tasks[0].isCompleted, "incomplete task state")
}

func testArchiveKeepsExistingArchivesAndCreatesANewCurrentPlan() throws {
    let oldDate = Date(timeIntervalSince1970: 1_600_000_000)
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let existingArchive = ArchiveDay(
        archiveDate: oldDate,
        sourcePlanningDate: oldDate,
        groupsSnapshot: [DailyPlanGroup(title: "Old", sortOrder: 0)]
    )
    let plan = DailyPlan(
        planningDate: oldDate,
        groups: [DailyPlanGroup(title: "Today", sortOrder: 0, tasks: [DailyTask(title: "Ship", sortOrder: 0)])]
    )

    let result = ArchiveService.archive(plan: plan, existingArchives: [existingArchive], now: now)

    try expectEqual(result.archives.count, 2, "existing archive plus new archive")
    try expectEqual(result.archives[0], existingArchive, "existing archive preserved")
    try expectEqual(result.archives[1].groupsSnapshot[0].title, "Today", "new archive appended")
    try expectEqual(result.current.planningDate, now, "new current plan date")
    try expect(result.current.groups.isEmpty, "new current plan groups")
}

func testSingleInstanceGuardRequiresExclusiveLock() throws {
    let url = try temporaryDatabaseURL("sidenotes.lock")
    var firstGuard: SingleInstanceGuard? = try SingleInstanceGuard(lockURL: url)
    try expect(firstGuard != nil, "first guard should acquire the lock")

    do {
        _ = try SingleInstanceGuard(lockURL: url)
        throw TestFailure(description: "second guard should not acquire an active lock")
    } catch SingleInstanceGuard.Error.alreadyRunning {
        // Expected: a live SideNotes instance already owns this lock.
    }

    firstGuard = nil
    let replacementGuard = try SingleInstanceGuard(lockURL: url)
    _ = replacementGuard
}

func temporaryDatabaseURL(_ name: String) throws -> URL {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("SideNotesCoreTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent(name)
}

func testPlanStorePersistsDailyGroupsTasksAndSettings() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    let store = try PlanStore(databaseURL: url)

    let group = try store.addDailyGroup(title: "Work")
    let task = try store.addDailyTask(groupID: group.id, title: "Prepare plan")
    _ = try store.toggleTask(id: task.id)
    var settings = try store.loadSettings()
    settings.isPinned = true
    settings.visibleSide = .back
    settings.cardOpacity = 0.52
    settings.cardCornerRadius = 36
    try store.saveSettings(settings)

    let reopened = try PlanStore(databaseURL: url)
    let plan = try reopened.loadDailyPlan()
    let reopenedSettings = try reopened.loadSettings()

    try expectEqual(plan.groups.count, 1, "daily group count")
    try expectEqual(plan.groups[0].title, "Work", "daily group title")
    try expectEqual(plan.groups[0].tasks.count, 1, "daily task count")
    try expectEqual(plan.groups[0].tasks[0].title, "Prepare plan", "daily task title")
    try expect(plan.groups[0].tasks[0].isCompleted, "daily task completion persisted")
    try expect(reopenedSettings.isPinned, "pinned state persisted")
    try expectEqual(reopenedSettings.visibleSide, .back, "visible side persisted")
    try expectEqual(reopenedSettings.cardOpacity, 0.52, accuracy: 0.001, "opacity persisted")
    try expectEqual(reopenedSettings.cardCornerRadius, 36, accuracy: 0.001, "corner radius persisted")
}

func testPlanStorePersistsLongTermAreasAndItems() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    let store = try PlanStore(databaseURL: url)

    let reading = try store.addLongTermArea(title: "Reading")
    _ = try store.addLongTermItem(areaID: reading.id, title: "Read Designing Your Life")
    let english = try store.addLongTermArea(title: "English")
    _ = try store.addLongTermItem(areaID: english.id, title: "Listen 20 minutes daily")

    let reopened = try PlanStore(databaseURL: url)
    let areas = try reopened.loadLongTermAreas()

    try expectEqual(areas.map { $0.title }, ["Reading", "English"], "long-term area order")
    try expectEqual(areas[0].items.map { $0.title }, ["Read Designing Your Life"], "reading item")
    try expectEqual(areas[1].items.map { $0.title }, ["Listen 20 minutes daily"], "english item")
}

func testPlanStoreArchivesCurrentPlanAndSearchesHistory() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    let store = try PlanStore(databaseURL: url)
    let group = try store.addDailyGroup(title: "Social")
    _ = try store.addDailyTask(groupID: group.id, title: "Message Alex")
    _ = try store.addDailyTask(groupID: group.id, title: "Book dinner")

    let archive = try store.archiveCurrentPlan(now: Date(timeIntervalSince1970: 1_700_000_000))
    let current = try store.loadDailyPlan()
    let archives = try store.loadArchives()
    let searchResults = try store.searchArchives(query: "alex")

    try expect(current.groups.isEmpty, "current plan cleared after archive")
    try expectEqual(archives.count, 1, "archive count after store archive")
    try expectEqual(archives[0].id, archive.id, "stored archive id")
    try expectEqual(archives[0].groupsSnapshot[0].title, "Social", "archive group title")
    try expectEqual(archives[0].groupsSnapshot[0].tasks.map { $0.title }, ["Message Alex", "Book dinner"], "archive task order")
    try expectEqual(searchResults.count, 1, "archive search count")
    try expectEqual(searchResults[0].id, archive.id, "archive search result id")
}

func testPlanStoreEditsDeletesAndReordersDailyPlan() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    let store = try PlanStore(databaseURL: url)

    let work = try store.addDailyGroup(title: "Work")
    let learning = try store.addDailyGroup(title: "Learning")
    let first = try store.addDailyTask(groupID: work.id, title: "First")
    let second = try store.addDailyTask(groupID: work.id, title: "Second")

    try store.renameDailyGroup(id: work.id, title: "Deep Work")
    try store.renameDailyTask(id: first.id, title: "Focus block")
    try store.moveDailyTask(id: second.id, toSortOrder: 0)
    try store.moveDailyGroup(id: learning.id, toSortOrder: 0)
    try store.deleteDailyTask(id: first.id)

    let planAfterEdits = try store.loadDailyPlan()
    try expectEqual(planAfterEdits.groups.map { $0.title }, ["Learning", "Deep Work"], "daily group reorder and rename")
    try expectEqual(planAfterEdits.groups[1].tasks.map { $0.title }, ["Second"], "daily task delete")

    try store.deleteDailyGroup(id: learning.id)
    let planAfterDelete = try store.loadDailyPlan()
    try expectEqual(planAfterDelete.groups.map { $0.title }, ["Deep Work"], "daily group delete")
}

func testPlanStoreEditsDeletesAndReordersLongTermAreas() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    let store = try PlanStore(databaseURL: url)

    let reading = try store.addLongTermArea(title: "Reading")
    let english = try store.addLongTermArea(title: "English")
    let first = try store.addLongTermItem(areaID: reading.id, title: "Book A")
    let second = try store.addLongTermItem(areaID: reading.id, title: "Book B")

    try store.renameLongTermArea(id: reading.id, title: "Books")
    try store.renameLongTermItem(id: first.id, title: "Designing Your Life")
    try store.moveLongTermArea(id: english.id, toSortOrder: 0)
    try store.moveLongTermItem(id: second.id, toSortOrder: 0)
    try store.deleteLongTermItem(id: first.id)

    let areasAfterEdits = try store.loadLongTermAreas()
    try expectEqual(areasAfterEdits.map { $0.title }, ["English", "Books"], "long-term area reorder and rename")
    try expectEqual(areasAfterEdits[1].items.map { $0.title }, ["Book B"], "long-term item delete")

    try store.deleteLongTermArea(id: english.id)
    let areasAfterDelete = try store.loadLongTermAreas()
    try expectEqual(areasAfterDelete.map { $0.title }, ["Books"], "long-term area delete")
}

let tests: [(String, () throws -> Void)] = [
    ("default settings are readable and usable", testDefaultSettingsAreReadableAndUsable),
    ("appearance settings clamp to readable ranges", testAppearanceSettingsClampToReadableRanges),
    ("window frame outside screens falls back to default", testWindowFrameOutsideScreensFallsBackToDefault),
    ("card size updates clamp to readable ranges", testCardSizeUpdatesClampToReadableRanges),
    ("archive preserves groups, tasks, order, and completion", testArchivePreservesGroupsTasksOrderAndCompletion),
    ("archive keeps existing archives and creates a new current plan", testArchiveKeepsExistingArchivesAndCreatesANewCurrentPlan),
    ("single instance guard requires exclusive lock", testSingleInstanceGuardRequiresExclusiveLock),
    ("plan store persists daily groups, tasks, and settings", testPlanStorePersistsDailyGroupsTasksAndSettings),
    ("plan store persists long-term areas and items", testPlanStorePersistsLongTermAreasAndItems),
    ("plan store archives current plan and searches history", testPlanStoreArchivesCurrentPlanAndSearchesHistory),
    ("plan store edits, deletes, and reorders daily plan", testPlanStoreEditsDeletesAndReordersDailyPlan),
    ("plan store edits, deletes, and reorders long-term areas", testPlanStoreEditsDeletesAndReordersLongTermAreas)
]

var failures: [String] = []

for (name, test) in tests {
    do {
        try test()
        print("PASS \(name)")
    } catch {
        failures.append("FAIL \(name): \(error)")
    }
}

if failures.isEmpty {
    print("All \(tests.count) SideNotesCore tests passed.")
} else {
    failures.forEach { print($0) }
    exit(1)
}
