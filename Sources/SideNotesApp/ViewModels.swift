import Foundation
import SwiftUI
import SideNotesCore

enum EditorTab: Hashable {
    case today
    case longTerm
    case archives
    case appearance
}

@MainActor
final class PlanViewModel: ObservableObject {
    @Published var dailyPlan: DailyPlan
    @Published var longTermAreas: [LongTermArea]
    @Published var archives: [ArchiveDay]
    @Published var archiveSearchResults: [ArchiveDay]
    @Published var settings: AppSettings
    @Published var errorMessage: String?
    @Published var editorTab: EditorTab

    let store: PlanStore
    private var currentArchiveQuery = ""
    private var persistedSettings = AppSettings.defaults()

    init(store: PlanStore) {
        self.store = store
        dailyPlan = DailyPlan()
        longTermAreas = []
        archives = []
        archiveSearchResults = []
        settings = .defaults()
        editorTab = .today
        reload()
    }

    func reload() {
        do {
            dailyPlan = try store.loadDailyPlan()
            longTermAreas = try store.loadLongTermAreas()
            archives = try store.loadArchives()
            archiveSearchResults = filteredArchives(archives, query: currentArchiveQuery)
            settings = try store.loadSettings()
            persistedSettings = settings
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func flipCard() {
        settings.visibleSide = settings.visibleSide == .front ? .back : .front
        saveSettings()
    }

    func setPinned(_ isPinned: Bool) {
        settings.isPinned = isPinned
        saveSettings()
    }

    func setTriggerSide(_ triggerSide: TriggerSide) {
        settings.triggerSide = triggerSide
        saveSettings()
    }

    func setCardOpacity(_ opacity: Double) {
        settings.cardOpacity = opacity
        settings.validate()
        saveSettings()
    }

    func setCardCornerRadius(_ radius: Double) {
        settings.cardCornerRadius = radius
        settings.validate()
        saveSettings()
    }

    func setCardSize(_ size: CGSize) {
        settings.setCardSize(width: size.width, height: size.height)
        saveSettings()
    }

    func setCardFrame(_ frame: StoredRect, visibleFrames: [StoredRect] = []) {
        settings.cardFrame = frame
        settings.validate(visibleFrames: visibleFrames)
        saveSettings()
    }

    func setEditorFrame(_ frame: StoredRect, visibleFrames: [StoredRect] = []) {
        settings.editorFrame = frame
        settings.validate(visibleFrames: visibleFrames)
        saveSettings()
    }

    func validateWindowFrames(visibleFrames: [StoredRect]) {
        let original = settings
        settings.validate(visibleFrames: visibleFrames)
        if settings != original {
            saveSettings()
        }
    }

    func addDailyGroup(title: String) -> Bool {
        guard !title.trimmed.isEmpty else { return rejectBlankInput() }
        return performAndReload {
            _ = try store.addDailyGroup(title: title.trimmed)
        }
    }

    func renameDailyGroup(id: UUID, title: String) -> Bool {
        guard !title.trimmed.isEmpty else { return rejectBlankInput() }
        guard currentDailyGroupTitle(id: id) != title.trimmed else { return acceptUnchangedInput() }
        return performAndReload {
            try store.renameDailyGroup(id: id, title: title.trimmed)
        }
    }

    func moveDailyGroup(id: UUID, toSortOrder sortOrder: Int) {
        performAndReload {
            try store.moveDailyGroup(id: id, toSortOrder: sortOrder)
        }
    }

    func deleteDailyGroup(id: UUID) {
        performAndReload {
            try store.deleteDailyGroup(id: id)
        }
    }

    func addDailyTask(groupID: UUID, title: String) -> Bool {
        guard !title.trimmed.isEmpty else { return rejectBlankInput() }
        return performAndReload {
            _ = try store.addDailyTask(groupID: groupID, title: title.trimmed)
        }
    }

    func renameDailyTask(id: UUID, title: String) -> Bool {
        guard !title.trimmed.isEmpty else { return rejectBlankInput() }
        guard currentDailyTaskTitle(id: id) != title.trimmed else { return acceptUnchangedInput() }
        return performAndReload {
            try store.renameDailyTask(id: id, title: title.trimmed)
        }
    }

    func moveDailyTask(id: UUID, toSortOrder sortOrder: Int) {
        performAndReload {
            try store.moveDailyTask(id: id, toSortOrder: sortOrder)
        }
    }

    func deleteDailyTask(id: UUID) {
        performAndReload {
            try store.deleteDailyTask(id: id)
        }
    }

    func toggleTask(_ task: DailyTask) {
        performAndReload {
            _ = try store.toggleTask(id: task.id)
        }
    }

    func addLongTermArea(title: String) -> Bool {
        guard !title.trimmed.isEmpty else { return rejectBlankInput() }
        return performAndReload {
            _ = try store.addLongTermArea(title: title.trimmed)
        }
    }

    func renameLongTermArea(id: UUID, title: String) -> Bool {
        guard !title.trimmed.isEmpty else { return rejectBlankInput() }
        guard currentLongTermAreaTitle(id: id) != title.trimmed else { return acceptUnchangedInput() }
        return performAndReload {
            try store.renameLongTermArea(id: id, title: title.trimmed)
        }
    }

    func moveLongTermArea(id: UUID, toSortOrder sortOrder: Int) {
        performAndReload {
            try store.moveLongTermArea(id: id, toSortOrder: sortOrder)
        }
    }

    func deleteLongTermArea(id: UUID) {
        performAndReload {
            try store.deleteLongTermArea(id: id)
        }
    }

    func addLongTermItem(areaID: UUID, title: String) -> Bool {
        guard !title.trimmed.isEmpty else { return rejectBlankInput() }
        return performAndReload {
            _ = try store.addLongTermItem(areaID: areaID, title: title.trimmed)
        }
    }

    func renameLongTermItem(id: UUID, title: String) -> Bool {
        guard !title.trimmed.isEmpty else { return rejectBlankInput() }
        guard currentLongTermItemTitle(id: id) != title.trimmed else { return acceptUnchangedInput() }
        return performAndReload {
            try store.renameLongTermItem(id: id, title: title.trimmed)
        }
    }

    func moveLongTermItem(id: UUID, toSortOrder sortOrder: Int) {
        performAndReload {
            try store.moveLongTermItem(id: id, toSortOrder: sortOrder)
        }
    }

    func deleteLongTermItem(id: UUID) {
        performAndReload {
            try store.deleteLongTermItem(id: id)
        }
    }

    func archiveCurrentPlan() {
        performAndReload {
            _ = try store.archiveCurrentPlan()
        }
    }

    func searchArchives(_ query: String) {
        currentArchiveQuery = query
        archiveSearchResults = filteredArchives(archives, query: query)
        errorMessage = nil
    }

    private func saveSettings() {
        do {
            try store.saveSettings(settings)
            settings = try store.loadSettings()
            persistedSettings = settings
            errorMessage = nil
        } catch {
            settings = persistedSettings
            errorMessage = error.localizedDescription
        }
    }

    private func rejectBlankInput() -> Bool {
        errorMessage = nil
        return false
    }

    private func acceptUnchangedInput() -> Bool {
        errorMessage = nil
        return true
    }

    @discardableResult
    private func performAndReload(_ operation: () throws -> Void) -> Bool {
        do {
            try operation()
            reload()
            return true
        } catch {
            let message = error.localizedDescription
            reload()
            errorMessage = message
            return false
        }
    }

    private func filteredArchives(_ archives: [ArchiveDay], query: String) -> [ArchiveDay] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else {
            return archives
        }
        return archives.filter { archive in
            archive.groupsSnapshot.contains { group in
                group.title.lowercased().contains(needle)
                    || group.tasks.contains { $0.title.lowercased().contains(needle) }
            }
        }
    }

    private func currentDailyGroupTitle(id: UUID) -> String? {
        dailyPlan.groups.first { $0.id == id }?.title
    }

    private func currentDailyTaskTitle(id: UUID) -> String? {
        dailyPlan.groups
            .flatMap(\.tasks)
            .first { $0.id == id }?
            .title
    }

    private func currentLongTermAreaTitle(id: UUID) -> String? {
        longTermAreas.first { $0.id == id }?.title
    }

    private func currentLongTermItemTitle(id: UUID) -> String? {
        longTermAreas
            .flatMap(\.items)
            .first { $0.id == id }?
            .title
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
