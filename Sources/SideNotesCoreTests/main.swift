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

func testSettingsDecodeMissingKeysUsesReadableDefaults() throws {
    let json = """
    {
      "triggerSide": "left",
      "isPinned": false,
      "visibleSide": "back",
      "cardFrame": { "x": 80, "y": 90, "width": 410, "height": 620 }
    }
    """
    let decoder = JSONDecoder()

    var settings = try decoder.decode(AppSettings.self, from: Data(json.utf8))
    settings.validate()

    try expectEqual(settings.triggerSide, .left, "decoded trigger side")
    try expect(!settings.isPinned, "decoded pinned state")
    try expectEqual(settings.visibleSide, .back, "decoded visible side")
    try expectEqual(settings.cardFrame, StoredRect(x: 80, y: 90, width: 410, height: 620), "decoded card frame")
    try expectEqual(settings.editorFrame, AppSettings.defaults().editorFrame, "missing editor frame default")
    try expectEqual(settings.cardOpacity, AppSettings.defaults().cardOpacity, accuracy: 0.001, "missing opacity default")
    try expectEqual(settings.cardCornerRadius, AppSettings.defaults().cardCornerRadius, accuracy: 0.001, "missing corner default")
}

func testSettingsDecodeInvalidValuesUsesDefaultsAndValidation() throws {
    let json = """
    {
      "triggerSide": "top",
      "isPinned": true,
      "visibleSide": "inside",
      "cardOpacity": 12,
      "cardCornerRadius": -4,
      "cardFrame": { "x": 20, "y": 30, "width": 100, "height": 200 },
      "editorFrame": { "x": 40, "y": 50, "width": 200, "height": 300 }
    }
    """
    let decoder = JSONDecoder()

    var settings = try decoder.decode(AppSettings.self, from: Data(json.utf8))
    settings.validate()

    try expectEqual(settings.triggerSide, AppSettings.defaults().triggerSide, "invalid trigger side default")
    try expectEqual(settings.visibleSide, AppSettings.defaults().visibleSide, "invalid visible side default")
    try expectEqual(settings.cardOpacity, 1, accuracy: 0.001, "invalid opacity clamped")
    try expectEqual(settings.cardCornerRadius, 4, accuracy: 0.001, "invalid corner clamped")
    try expectEqual(settings.cardFrame.width, 260, accuracy: 0.001, "invalid card width clamped")
    try expectEqual(settings.cardFrame.height, 360, accuracy: 0.001, "invalid card height clamped")
    try expectEqual(settings.editorFrame.width, 640, accuracy: 0.001, "invalid editor width clamped")
    try expectEqual(settings.editorFrame.height, 480, accuracy: 0.001, "invalid editor height clamped")
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
    settings.editorFrame = StoredRect(x: -8_000, y: -8_000, width: 920, height: 680)

    settings.validate(visibleFrames: [
        StoredRect(x: 0, y: 0, width: 1_440, height: 900)
    ])

    try expectEqual(settings.cardFrame.x, 1_088, accuracy: 0.001, "fallback x")
    try expectEqual(settings.cardFrame.y, 160, accuracy: 0.001, "fallback y")
    try expectEqual(settings.cardFrame.width, 320, accuracy: 0.001, "fallback width")
    try expectEqual(settings.cardFrame.height, 580, accuracy: 0.001, "fallback height")
    try expectEqual(settings.editorFrame.x, 220, accuracy: 0.001, "fallback editor x")
    try expectEqual(settings.editorFrame.y, 140, accuracy: 0.001, "fallback editor y")
    try expectEqual(settings.editorFrame.width, 920, accuracy: 0.001, "fallback editor width")
    try expectEqual(settings.editorFrame.height, 680, accuracy: 0.001, "fallback editor height")
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

func testWindowFrameUpdatesPreservePositionAndClampSize() throws {
    var settings = AppSettings.defaults()

    settings.setCardFrame(StoredRect(x: 120, y: 240, width: 1_000, height: 1_200))
    try expectEqual(settings.cardFrame.x, 120, accuracy: 0.001, "card frame x preserved")
    try expectEqual(settings.cardFrame.y, 240, accuracy: 0.001, "card frame y preserved")
    try expectEqual(settings.cardFrame.width, 720, accuracy: 0.001, "card frame width clamped")
    try expectEqual(settings.cardFrame.height, 900, accuracy: 0.001, "card frame height clamped")

    settings.setEditorFrame(StoredRect(x: 260, y: 180, width: 2_000, height: 2_000))
    try expectEqual(settings.editorFrame.x, 260, accuracy: 0.001, "editor frame x preserved")
    try expectEqual(settings.editorFrame.y, 180, accuracy: 0.001, "editor frame y preserved")
    try expectEqual(settings.editorFrame.width, 1_400, accuracy: 0.001, "editor frame width clamped")
    try expectEqual(settings.editorFrame.height, 1_100, accuracy: 0.001, "editor frame height clamped")
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
    settings.cardFrame = StoredRect(x: 99, y: 88, width: 420, height: 640)
    settings.editorFrame = StoredRect(x: 77, y: 66, width: 880, height: 620)
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
    try expectEqual(reopenedSettings.cardFrame, StoredRect(x: 99, y: 88, width: 420, height: 640), "card frame persisted")
    try expectEqual(reopenedSettings.editorFrame, StoredRect(x: 77, y: 66, width: 880, height: 620), "editor frame persisted")
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

func testPlanStoreRejectsReorderOfMissingDailyGroupWithoutChangingOrder() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    let store = try PlanStore(databaseURL: url)

    _ = try store.addDailyGroup(title: "Work")
    _ = try store.addDailyGroup(title: "Learning")

    do {
        try store.moveDailyGroup(id: UUID(), toSortOrder: 0)
        throw TestFailure(description: "missing daily group reorder should fail")
    } catch {
        // Expected: stale UI events should not rewrite existing sort orders.
    }

    let plan = try store.loadDailyPlan()
    try expectEqual(plan.groups.map { $0.title }, ["Work", "Learning"], "daily group order unchanged after missing reorder")
    try expectEqual(plan.groups.map { $0.sortOrder }, [0, 1], "daily group sort orders unchanged after missing reorder")
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

func testPlanStoreRejectsReorderOfMissingLongTermAreaWithoutChangingOrder() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    let store = try PlanStore(databaseURL: url)

    _ = try store.addLongTermArea(title: "Reading")
    _ = try store.addLongTermArea(title: "English")

    do {
        try store.moveLongTermArea(id: UUID(), toSortOrder: 0)
        throw TestFailure(description: "missing long-term area reorder should fail")
    } catch {
        // Expected: stale UI events should not rewrite existing sort orders.
    }

    let areas = try store.loadLongTermAreas()
    try expectEqual(areas.map { $0.title }, ["Reading", "English"], "long-term area order unchanged after missing reorder")
    try expectEqual(areas.map { $0.sortOrder }, [0, 1], "long-term area sort orders unchanged after missing reorder")
}

let tests: [(String, () throws -> Void)] = [
    ("default settings are readable and usable", testDefaultSettingsAreReadableAndUsable),
    ("settings decode missing keys uses readable defaults", testSettingsDecodeMissingKeysUsesReadableDefaults),
    ("settings decode invalid values uses defaults and validation", testSettingsDecodeInvalidValuesUsesDefaultsAndValidation),
    ("appearance settings clamp to readable ranges", testAppearanceSettingsClampToReadableRanges),
    ("window frame outside screens falls back to default", testWindowFrameOutsideScreensFallsBackToDefault),
    ("card size updates clamp to readable ranges", testCardSizeUpdatesClampToReadableRanges),
    ("window frame updates preserve position and clamp size", testWindowFrameUpdatesPreservePositionAndClampSize),
    ("archive preserves groups, tasks, order, and completion", testArchivePreservesGroupsTasksOrderAndCompletion),
    ("archive keeps existing archives and creates a new current plan", testArchiveKeepsExistingArchivesAndCreatesANewCurrentPlan),
    ("single instance guard requires exclusive lock", testSingleInstanceGuardRequiresExclusiveLock),
    ("plan store persists daily groups, tasks, and settings", testPlanStorePersistsDailyGroupsTasksAndSettings),
    ("plan store persists long-term areas and items", testPlanStorePersistsLongTermAreasAndItems),
    ("plan store archives current plan and searches history", testPlanStoreArchivesCurrentPlanAndSearchesHistory),
    ("plan store edits, deletes, and reorders daily plan", testPlanStoreEditsDeletesAndReordersDailyPlan),
    ("plan store rejects reorder of missing daily group without changing order", testPlanStoreRejectsReorderOfMissingDailyGroupWithoutChangingOrder),
    ("plan store edits, deletes, and reorders long-term areas", testPlanStoreEditsDeletesAndReordersLongTermAreas),
    ("plan store rejects reorder of missing long-term area without changing order", testPlanStoreRejectsReorderOfMissingLongTermAreaWithoutChangingOrder)
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
