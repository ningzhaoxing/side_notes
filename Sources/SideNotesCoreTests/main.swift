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

func expectThrows(_ message: String, _ operation: () throws -> Void) throws {
    var didThrow = false
    do {
        try operation()
    } catch {
        didThrow = true
    }
    try expect(didThrow, message)
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

func executeSQLite(url: URL, sql: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [url.path, sql]
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
        throw TestFailure(description: "sqlite3 command failed with status \(process.terminationStatus)")
    }
}

func executeSQLiteScalar(url: URL, sql: String) throws -> String {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [url.path, sql]
    process.standardOutput = output
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
        throw TestFailure(description: "sqlite3 scalar command failed with status \(process.terminationStatus)")
    }
    let data = output.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func readWorkspaceFile(_ path: String) throws -> String {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(path)
    return try String(contentsOf: url, encoding: .utf8)
}

func sourceSection(_ source: String, from startMarker: String, to endMarker: String) throws -> String {
    guard let start = source.range(of: startMarker) else {
        throw TestFailure(description: "missing source marker \(startMarker)")
    }
    guard let end = source[start.upperBound...].range(of: endMarker) else {
        throw TestFailure(description: "missing source marker \(endMarker)")
    }
    return String(source[start.upperBound..<end.lowerBound])
}

func testUserVisibleLongTermSurfacesRenderErrors() throws {
    let cardSource = try readWorkspaceFile("Sources/SideNotesApp/PlanCardView.swift")
    let editorSource = try readWorkspaceFile("Sources/SideNotesApp/EditorView.swift")
    let cardBackSide = try sourceSection(cardSource, from: "private var backSide", to: "private func emptyState")
    let longTermEditor = try sourceSection(editorSource, from: "private var longTermEditor", to: "private var archiveBrowser")

    try expect(cardBackSide.contains("errorMessage"), "card back side should render view model errors")
    try expect(longTermEditor.contains("errorMessage"), "long-term editor should render view model errors")
}

func testEditorArchiveAndAppearanceSurfacesRenderErrors() throws {
    let editorSource = try readWorkspaceFile("Sources/SideNotesApp/EditorView.swift")
    let archiveBrowser = try sourceSection(editorSource, from: "private var archiveBrowser", to: "private var appearanceEditor")
    let appearanceEditor = try sourceSection(editorSource, from: "private var appearanceEditor", to: "private struct DailyGroupEditor")

    try expect(archiveBrowser.contains("errorMessage"), "archive browser should render view model errors")
    try expect(appearanceEditor.contains("errorMessage"), "appearance editor should render view model errors")
}

func testViewModelReloadPreservesArchiveSearchQuery() throws {
    let source = try readWorkspaceFile("Sources/SideNotesApp/ViewModels.swift")
    let reload = try sourceSection(source, from: "func reload()", to: "func flipCard()")
    let searchArchives = try sourceSection(source, from: "func searchArchives", to: "private func saveSettings")

    try expect(source.contains("currentArchiveQuery"), "view model should track current archive search query")
    try expect(reload.contains("currentArchiveQuery"), "reload should apply current archive search query")
    try expect(!reload.contains("archiveSearchResults = archives"), "reload should not reset filtered archive results to all archives")
    try expect(searchArchives.contains("currentArchiveQuery = query"), "search should remember the current archive query")
}

func testViewModelRollsBackSettingsWhenSaveFails() throws {
    let source = try readWorkspaceFile("Sources/SideNotesApp/ViewModels.swift")
    let saveSettings = try sourceSection(source, from: "private func saveSettings", to: "private func performAndReload")

    try expect(source.contains("persistedSettings"), "view model should keep last persisted settings")
    try expect(saveSettings.contains("persistedSettings = settings"), "successful save should refresh persisted settings")
    try expect(saveSettings.contains("settings = persistedSettings"), "failed save should roll back optimistic settings")
}

func testPinToggleUsesSettingsAfterSaveAttempt() throws {
    let source = try readWorkspaceFile("Sources/SideNotesApp/PlanCardView.swift")
    let controls = try sourceSection(source, from: "private var controls", to: "private func toolbarButton")

    try expect(controls.contains("viewModel.setPinned(next)"), "pin button should ask view model to persist desired state")
    try expect(controls.contains("onPinToggle(viewModel.settings.isPinned)"), "pin window state should use persisted or rolled-back settings")
    try expect(!controls.contains("onPinToggle(next)"), "pin window state should not use optimistic next value after possible rollback")
}

func testAddInputsClearOnlyAfterSuccessfulSave() throws {
    let viewModelSource = try readWorkspaceFile("Sources/SideNotesApp/ViewModels.swift")
    let cardSource = try readWorkspaceFile("Sources/SideNotesApp/PlanCardView.swift")
    let editorSource = try readWorkspaceFile("Sources/SideNotesApp/EditorView.swift")

    try expect(viewModelSource.contains("func addDailyGroup(title: String) -> Bool"), "daily group add should report success")
    try expect(viewModelSource.contains("func addDailyTask(groupID: UUID, title: String) -> Bool"), "daily task add should report success")
    try expect(viewModelSource.contains("func addLongTermArea(title: String) -> Bool"), "long-term area add should report success")
    try expect(viewModelSource.contains("func addLongTermItem(areaID: UUID, title: String) -> Bool"), "long-term item add should report success")

    try expect(cardSource.contains("if viewModel.addDailyGroup(title: newGroupTitle)"), "card daily group input should clear only after successful add")
    try expect(cardSource.contains("if viewModel.addDailyTask(groupID: group.id, title: newTaskTitle)"), "card daily task input should clear only after successful add")
    try expect(cardSource.contains("if viewModel.addLongTermArea(title: newAreaTitle)"), "card long-term area input should clear only after successful add")
    try expect(cardSource.contains("if viewModel.addLongTermItem(areaID: area.id, title: newItemTitle)"), "card long-term item input should clear only after successful add")
    try expect(editorSource.contains("if viewModel.addDailyGroup(title: newGroupTitle)"), "editor daily group input should clear only after successful add")
    try expect(editorSource.contains("if viewModel.addDailyTask(groupID: group.id, title: newTaskTitle)"), "editor daily task input should clear only after successful add")
    try expect(editorSource.contains("if viewModel.addLongTermArea(title: newAreaTitle)"), "editor long-term area input should clear only after successful add")
    try expect(editorSource.contains("if viewModel.addLongTermItem(areaID: area.id, title: newItemTitle)"), "editor long-term item input should clear only after successful add")
}

func testPlanCardWindowShowAndBookmarkAreIdempotent() throws {
    let source = try readWorkspaceFile("Sources/SideNotesApp/PlanCardWindowController.swift")
    let show = try sourceSection(source, from: "func show()", to: "func hide()")
    let showBookmark = try sourceSection(source, from: "func showBookmark()", to: "func hideBookmark()")

    try expect(show.contains("guard !window.isVisible || isCollapsed else"), "expanded card show should not rebuild or animate an already visible card")
    try expect(show.contains("window.orderFrontRegardless()"), "expanded card show should still bring the existing window forward")
    try expect(showBookmark.contains("guard !window.isVisible || !isCollapsed else"), "bookmark show should not rebuild or animate an already visible handle")
    try expect(showBookmark.contains("window.orderFrontRegardless()"), "bookmark show should still bring the existing handle forward")
}

func testRenameInputsRevertAfterFailedSave() throws {
    let viewModelSource = try readWorkspaceFile("Sources/SideNotesApp/ViewModels.swift")
    let cardSource = try readWorkspaceFile("Sources/SideNotesApp/PlanCardView.swift")
    let editorSource = try readWorkspaceFile("Sources/SideNotesApp/EditorView.swift")

    try expect(viewModelSource.contains("func renameDailyGroup(id: UUID, title: String) -> Bool"), "daily group rename should report success")
    try expect(viewModelSource.contains("func renameDailyTask(id: UUID, title: String) -> Bool"), "daily task rename should report success")
    try expect(viewModelSource.contains("func renameLongTermArea(id: UUID, title: String) -> Bool"), "long-term area rename should report success")
    try expect(viewModelSource.contains("func renameLongTermItem(id: UUID, title: String) -> Bool"), "long-term item rename should report success")

    try expect(cardSource.contains("if !viewModel.renameDailyGroup(id: group.id, title: title) {\n            title = group.title\n        }"), "card daily group title should revert after failed rename")
    try expect(cardSource.contains("if !viewModel.renameDailyTask(id: task.id, title: title) {\n            title = task.title\n        }"), "card daily task title should revert after failed rename")
    try expect(cardSource.contains("if !viewModel.renameLongTermArea(id: area.id, title: title) {\n            title = area.title\n        }"), "card long-term area title should revert after failed rename")
    try expect(cardSource.contains("if !viewModel.renameLongTermItem(id: item.id, title: title) {\n            title = item.title\n        }"), "card long-term item title should revert after failed rename")

    try expect(editorSource.contains("if !viewModel.renameDailyGroup(id: group.id, title: groupTitle) {\n            groupTitle = group.title\n        }"), "editor daily group title should revert after failed rename")
    try expect(editorSource.contains("if !viewModel.renameDailyTask(id: task.id, title: title) {\n            title = task.title\n        }"), "editor daily task title should revert after failed rename")
    try expect(editorSource.contains("if !viewModel.renameLongTermArea(id: area.id, title: areaTitle) {\n            areaTitle = area.title\n        }"), "editor long-term area title should revert after failed rename")
    try expect(editorSource.contains("if !viewModel.renameLongTermItem(id: item.id, title: title) {\n            title = item.title\n        }"), "editor long-term item title should revert after failed rename")
}

func testViewModelSkipsUnchangedRenames() throws {
    let source = try readWorkspaceFile("Sources/SideNotesApp/ViewModels.swift")
    let renameDailyGroup = try sourceSection(source, from: "func renameDailyGroup", to: "func moveDailyGroup")
    let renameDailyTask = try sourceSection(source, from: "func renameDailyTask", to: "func moveDailyTask")
    let renameLongTermArea = try sourceSection(source, from: "func renameLongTermArea", to: "func moveLongTermArea")
    let renameLongTermItem = try sourceSection(source, from: "func renameLongTermItem", to: "func moveLongTermItem")

    try expect(renameDailyGroup.contains("currentDailyGroupTitle(id: id) != title"), "unchanged daily group title should not save and reload")
    try expect(renameDailyTask.contains("currentDailyTaskTitle(id: id) != title"), "unchanged daily task title should not save and reload")
    try expect(renameLongTermArea.contains("currentLongTermAreaTitle(id: id) != title"), "unchanged long-term area title should not save and reload")
    try expect(renameLongTermItem.contains("currentLongTermItemTitle(id: id) != title"), "unchanged long-term item title should not save and reload")
}

func testTriggerSideSettingIsEditableAndAppliedLive() throws {
    let viewModelSource = try readWorkspaceFile("Sources/SideNotesApp/ViewModels.swift")
    let editorSource = try readWorkspaceFile("Sources/SideNotesApp/EditorView.swift")
    let coordinatorSource = try readWorkspaceFile("Sources/SideNotesApp/AppCoordinator.swift")
    let edgeTriggerSource = try readWorkspaceFile("Sources/SideNotesApp/EdgeTriggerController.swift")
    let cardControllerSource = try readWorkspaceFile("Sources/SideNotesApp/PlanCardWindowController.swift")
    let appearanceEditor = try sourceSection(editorSource, from: "private var appearanceEditor", to: "private struct DailyGroupEditor")

    try expect(viewModelSource.contains("func setTriggerSide(_ triggerSide: TriggerSide)"), "view model should persist trigger side changes")
    try expect(appearanceEditor.contains("Picker(\"侧边位置\""), "appearance editor should expose trigger side choice")
    try expect(appearanceEditor.contains("viewModel.setTriggerSide($0)"), "trigger side picker should save through view model")
    try expect(coordinatorSource.contains("settingsCancellable"), "coordinator should observe live settings changes")
    try expect(coordinatorSource.contains("edgeTrigger?.setTriggerSide(settings.triggerSide)"), "coordinator should update edge trigger side live")
    try expect(coordinatorSource.contains("cardController.updateForSettingsChange"), "coordinator should let visible card or handle react to live setting changes")
    try expect(edgeTriggerSource.contains("func setTriggerSide(_ triggerSide: TriggerSide)"), "edge trigger should allow live side updates")
    try expect(cardControllerSource.contains("func updateForSettingsChange"), "card controller should reposition collapsed handle after settings changes")
}

func testExpandedUnpinnedCardRepositionsOnlyWhenTriggerSideChanges() throws {
    let coordinatorSource = try readWorkspaceFile("Sources/SideNotesApp/AppCoordinator.swift")
    let cardControllerSource = try readWorkspaceFile("Sources/SideNotesApp/PlanCardWindowController.swift")
    let applyLiveSettings = try sourceSection(coordinatorSource, from: "private func applyLiveSettings", to: "private func makeEditorWindow")
    let updateForSettingsChange = try sourceSection(cardControllerSource, from: "func updateForSettingsChange", to: "func showBookmark()")

    try expect(coordinatorSource.contains("lastAppliedSettings"), "coordinator should remember previous settings before live updates")
    try expect(applyLiveSettings.contains("settings.triggerSide != lastAppliedSettings.triggerSide"), "coordinator should detect real trigger side changes")
    try expect(applyLiveSettings.contains("repositionForTriggerSideChange: triggerSideChanged"), "coordinator should only request card reposition for trigger side changes")
    try expect(updateForSettingsChange.contains("repositionForTriggerSideChange: Bool"), "card controller should receive an explicit reposition reason")
    try expect(updateForSettingsChange.contains("window.isVisible, !viewModel.settings.isPinned"), "card controller should only move an expanded edge card, not a pinned card")
    try expect(updateForSettingsChange.contains("applyFrame(edgeFrame(), animate: false)"), "expanded unpinned card should move to the newly selected edge")
}

func testStaleInstanceTerminatorMatchesLegacyExecutables() throws {
    let source = try readWorkspaceFile("Sources/SideNotesApp/StaleInstanceTerminator.swift")

    try expect(source.contains("executableURL?.lastPathComponent"), "stale instance cleanup should match legacy bare SideNotes executables")
    try expect(source.contains("bundleURL?.lastPathComponent"), "stale instance cleanup should match copied SideNotes app bundles")
    try expect(source.contains("forceTerminate()"), "stale instance cleanup should force-terminate leftover old instances")
}

func testPlanStorePersistsDailyGroupsTasksAndSettings() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    let store = try PlanStore(databaseURL: url)

    let group = try store.addDailyGroup(title: "Work")
    let task = try store.addDailyTask(groupID: group.id, title: "Prepare plan")
    _ = try store.toggleTask(id: task.id)
    var settings = try store.loadSettings()
    settings.triggerSide = .left
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
    try expectEqual(reopenedSettings.triggerSide, .left, "trigger side persisted")
    try expect(reopenedSettings.isPinned, "pinned state persisted")
    try expectEqual(reopenedSettings.visibleSide, .back, "visible side persisted")
    try expectEqual(reopenedSettings.cardOpacity, 0.52, accuracy: 0.001, "opacity persisted")
    try expectEqual(reopenedSettings.cardCornerRadius, 36, accuracy: 0.001, "corner radius persisted")
    try expectEqual(reopenedSettings.cardFrame, StoredRect(x: 99, y: 88, width: 420, height: 640), "card frame persisted")
    try expectEqual(reopenedSettings.editorFrame, StoredRect(x: 77, y: 66, width: 880, height: 620), "editor frame persisted")
}

func testPlanStoreFallsBackToDefaultSettingsWhenStoredJSONIsInvalid() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    _ = try PlanStore(databaseURL: url)
    try executeSQLite(url: url, sql: "UPDATE settings SET value = 'not valid json' WHERE key = 'app';")

    let reopened = try PlanStore(databaseURL: url)
    let settings = try reopened.loadSettings()

    try expectEqual(settings, AppSettings.defaults(), "invalid settings json should use defaults")
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

func testPlanStoreSkipsCorruptArchiveSnapshotRows() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    let store = try PlanStore(databaseURL: url)
    let group = try store.addDailyGroup(title: "Work")
    _ = try store.addDailyTask(groupID: group.id, title: "Review plan")
    let goodArchive = try store.archiveCurrentPlan(now: Date(timeIntervalSince1970: 1_700_000_000))
    try executeSQLite(
        url: url,
        sql: """
        INSERT INTO archives (id, archive_date, source_planning_date, groups_snapshot, created_at)
        VALUES ('\(UUID().uuidString)', 1700000100, 1700000100, 'not valid json', 1700000100);
        """
    )

    let archives = try store.loadArchives()
    let searchResults = try store.searchArchives(query: "review")

    try expectEqual(archives.map { $0.id }, [goodArchive.id], "corrupt archive rows skipped")
    try expectEqual(searchResults.map { $0.id }, [goodArchive.id], "search ignores corrupt archive rows")
}

func testPlanStoreSkipsCorruptDailyRowsWhileKeepingGoodData() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    let store = try PlanStore(databaseURL: url)
    let group = try store.addDailyGroup(title: "Work")
    _ = try store.addDailyTask(groupID: group.id, title: "Keep this task")
    try executeSQLite(url: url, sql: "INSERT INTO daily_groups (id, title, sort_order) VALUES ('not-a-uuid', 'Broken group', 1);")
    try executeSQLite(
        url: url,
        sql: """
        INSERT INTO daily_tasks (id, group_id, title, is_completed, sort_order, created_at, updated_at)
        VALUES ('not-a-task-uuid', '\(group.id.uuidString)', 'Broken task', 0, 1, 1700000000, 1700000000);
        """
    )

    let plan = try store.loadDailyPlan()

    try expectEqual(plan.groups.map { $0.title }, ["Work"], "corrupt daily group rows skipped")
    try expectEqual(plan.groups[0].tasks.map { $0.title }, ["Keep this task"], "corrupt daily task rows skipped")
}

func testPlanStoreRecoversCorruptCurrentPlanID() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    _ = try PlanStore(databaseURL: url)
    try executeSQLite(url: url, sql: "UPDATE daily_plan SET id = 'not-a-plan-uuid' WHERE singleton = 1;")

    let reopened = try PlanStore(databaseURL: url)
    let plan = try reopened.loadDailyPlan()
    let repairedID = try executeSQLiteScalar(url: url, sql: "SELECT id FROM daily_plan WHERE singleton = 1;")

    try expectEqual(plan.groups.count, 0, "daily plan still loads with corrupt plan id")
    try expectEqual(repairedID, plan.id.uuidString, "corrupt plan id repaired in storage")
}

func testPlanStoreSkipsTasksWithCorruptGroupIDWhenToggling() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    let store = try PlanStore(databaseURL: url)
    let group = try store.addDailyGroup(title: "Work")
    let task = try store.addDailyTask(groupID: group.id, title: "Keep this task")
    try executeSQLite(url: url, sql: "UPDATE daily_tasks SET group_id = 'not-a-group-uuid' WHERE id = '\(task.id.uuidString)';")

    try expectThrows("toggle should reject task with corrupt group id") {
        _ = try store.toggleTask(id: task.id)
    }

    let plan = try store.loadDailyPlan()
    try expectEqual(plan.groups[0].tasks.count, 0, "corrupt-group task hidden from current plan")
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

    try expectThrows("missing daily group reorder should fail") {
        try store.moveDailyGroup(id: UUID(), toSortOrder: 0)
    }

    let plan = try store.loadDailyPlan()
    try expectEqual(plan.groups.map { $0.title }, ["Work", "Learning"], "daily group order unchanged after missing reorder")
    try expectEqual(plan.groups.map { $0.sortOrder }, [0, 1], "daily group sort orders unchanged after missing reorder")
}

func testPlanStoreRejectsMissingDailyRenameAndDeleteOperations() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    let store = try PlanStore(databaseURL: url)

    let group = try store.addDailyGroup(title: "Work")
    let task = try store.addDailyTask(groupID: group.id, title: "Keep this task")
    let missingID = UUID()

    try expectThrows("missing daily group rename should fail") {
        try store.renameDailyGroup(id: missingID, title: "Ghost group")
    }
    try expectThrows("missing daily group delete should fail") {
        try store.deleteDailyGroup(id: missingID)
    }
    try expectThrows("missing daily task rename should fail") {
        try store.renameDailyTask(id: missingID, title: "Ghost task")
    }
    try expectThrows("missing daily task delete should fail") {
        try store.deleteDailyTask(id: missingID)
    }

    let plan = try store.loadDailyPlan()
    try expectEqual(plan.groups.map { $0.title }, ["Work"], "daily group unchanged after missing operations")
    try expectEqual(plan.groups[0].tasks.map { $0.id }, [task.id], "daily task unchanged after missing operations")
}

func testStoreErrorsExposeReadableLocalizedDescriptions() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    let store = try PlanStore(databaseURL: url)

    do {
        try store.renameDailyGroup(id: UUID(), title: "Ghost group")
        throw TestFailure(description: "missing row should throw a store error")
    } catch let failure as TestFailure {
        throw failure
    } catch {
        try expect(
            error.localizedDescription.contains("missing value: daily group"),
            "store error should have readable localized description, got \(error.localizedDescription)"
        )
    }
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

    try expectThrows("missing long-term area reorder should fail") {
        try store.moveLongTermArea(id: UUID(), toSortOrder: 0)
    }

    let areas = try store.loadLongTermAreas()
    try expectEqual(areas.map { $0.title }, ["Reading", "English"], "long-term area order unchanged after missing reorder")
    try expectEqual(areas.map { $0.sortOrder }, [0, 1], "long-term area sort orders unchanged after missing reorder")
}

func testPlanStoreRejectsMissingLongTermRenameAndDeleteOperations() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    let store = try PlanStore(databaseURL: url)

    let area = try store.addLongTermArea(title: "Reading")
    let item = try store.addLongTermItem(areaID: area.id, title: "Keep this item")
    let missingID = UUID()

    try expectThrows("missing long-term area rename should fail") {
        try store.renameLongTermArea(id: missingID, title: "Ghost area")
    }
    try expectThrows("missing long-term area delete should fail") {
        try store.deleteLongTermArea(id: missingID)
    }
    try expectThrows("missing long-term item rename should fail") {
        try store.renameLongTermItem(id: missingID, title: "Ghost item")
    }
    try expectThrows("missing long-term item delete should fail") {
        try store.deleteLongTermItem(id: missingID)
    }

    let areas = try store.loadLongTermAreas()
    try expectEqual(areas.map { $0.title }, ["Reading"], "long-term area unchanged after missing operations")
    try expectEqual(areas[0].items.map { $0.id }, [item.id], "long-term item unchanged after missing operations")
}

func testPlanStoreSkipsCorruptLongTermRowsWhileKeepingGoodData() throws {
    let url = try temporaryDatabaseURL("store.sqlite")
    let store = try PlanStore(databaseURL: url)
    let area = try store.addLongTermArea(title: "Reading")
    _ = try store.addLongTermItem(areaID: area.id, title: "Keep this item")
    try executeSQLite(
        url: url,
        sql: """
        INSERT INTO long_term_areas (id, title, sort_order, created_at, updated_at)
        VALUES ('not-a-uuid', 'Broken area', 1, 1700000000, 1700000000);
        """
    )
    try executeSQLite(
        url: url,
        sql: """
        INSERT INTO long_term_items (id, area_id, title, sort_order, created_at, updated_at)
        VALUES ('not-an-item-uuid', '\(area.id.uuidString)', 'Broken item', 1, 1700000000, 1700000000);
        """
    )

    let areas = try store.loadLongTermAreas()

    try expectEqual(areas.map { $0.title }, ["Reading"], "corrupt long-term area rows skipped")
    try expectEqual(areas[0].items.map { $0.title }, ["Keep this item"], "corrupt long-term item rows skipped")
}

let tests: [(String, () throws -> Void)] = [
    ("default settings are readable and usable", testDefaultSettingsAreReadableAndUsable),
    ("settings decode missing keys uses readable defaults", testSettingsDecodeMissingKeysUsesReadableDefaults),
    ("settings decode invalid values uses defaults and validation", testSettingsDecodeInvalidValuesUsesDefaultsAndValidation),
    ("appearance settings clamp to readable ranges", testAppearanceSettingsClampToReadableRanges),
    ("window frame outside screens falls back to default", testWindowFrameOutsideScreensFallsBackToDefault),
    ("card size updates clamp to readable ranges", testCardSizeUpdatesClampToReadableRanges),
    ("window frame updates preserve position and clamp size", testWindowFrameUpdatesPreservePositionAndClampSize),
    ("user visible long-term surfaces render errors", testUserVisibleLongTermSurfacesRenderErrors),
    ("editor archive and appearance surfaces render errors", testEditorArchiveAndAppearanceSurfacesRenderErrors),
    ("view model reload preserves archive search query", testViewModelReloadPreservesArchiveSearchQuery),
    ("view model rolls back settings when save fails", testViewModelRollsBackSettingsWhenSaveFails),
    ("pin toggle uses settings after save attempt", testPinToggleUsesSettingsAfterSaveAttempt),
    ("add inputs clear only after successful save", testAddInputsClearOnlyAfterSuccessfulSave),
    ("plan card window show and bookmark are idempotent", testPlanCardWindowShowAndBookmarkAreIdempotent),
    ("rename inputs revert after failed save", testRenameInputsRevertAfterFailedSave),
    ("view model skips unchanged renames", testViewModelSkipsUnchangedRenames),
    ("trigger side setting is editable and applied live", testTriggerSideSettingIsEditableAndAppliedLive),
    ("expanded unpinned card repositions only when trigger side changes", testExpandedUnpinnedCardRepositionsOnlyWhenTriggerSideChanges),
    ("stale instance terminator matches legacy executables", testStaleInstanceTerminatorMatchesLegacyExecutables),
    ("archive preserves groups, tasks, order, and completion", testArchivePreservesGroupsTasksOrderAndCompletion),
    ("archive keeps existing archives and creates a new current plan", testArchiveKeepsExistingArchivesAndCreatesANewCurrentPlan),
    ("single instance guard requires exclusive lock", testSingleInstanceGuardRequiresExclusiveLock),
    ("plan store persists daily groups, tasks, and settings", testPlanStorePersistsDailyGroupsTasksAndSettings),
    ("plan store falls back to default settings when stored json is invalid", testPlanStoreFallsBackToDefaultSettingsWhenStoredJSONIsInvalid),
    ("plan store persists long-term areas and items", testPlanStorePersistsLongTermAreasAndItems),
    ("plan store archives current plan and searches history", testPlanStoreArchivesCurrentPlanAndSearchesHistory),
    ("plan store skips corrupt archive snapshot rows", testPlanStoreSkipsCorruptArchiveSnapshotRows),
    ("plan store skips corrupt daily rows while keeping good data", testPlanStoreSkipsCorruptDailyRowsWhileKeepingGoodData),
    ("plan store recovers corrupt current plan id", testPlanStoreRecoversCorruptCurrentPlanID),
    ("plan store skips tasks with corrupt group id when toggling", testPlanStoreSkipsTasksWithCorruptGroupIDWhenToggling),
    ("plan store edits, deletes, and reorders daily plan", testPlanStoreEditsDeletesAndReordersDailyPlan),
    ("plan store rejects reorder of missing daily group without changing order", testPlanStoreRejectsReorderOfMissingDailyGroupWithoutChangingOrder),
    ("plan store rejects missing daily rename and delete operations", testPlanStoreRejectsMissingDailyRenameAndDeleteOperations),
    ("store errors expose readable localized descriptions", testStoreErrorsExposeReadableLocalizedDescriptions),
    ("plan store edits, deletes, and reorders long-term areas", testPlanStoreEditsDeletesAndReordersLongTermAreas),
    ("plan store rejects reorder of missing long-term area without changing order", testPlanStoreRejectsReorderOfMissingLongTermAreaWithoutChangingOrder),
    ("plan store rejects missing long-term rename and delete operations", testPlanStoreRejectsMissingLongTermRenameAndDeleteOperations),
    ("plan store skips corrupt long-term rows while keeping good data", testPlanStoreSkipsCorruptLongTermRowsWhileKeepingGoodData)
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
