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
            archiveSearchResults = archives
            settings = try store.loadSettings()
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

    func addDailyGroup(title: String) {
        guard !title.trimmed.isEmpty else { return }
        performAndReload {
            _ = try store.addDailyGroup(title: title.trimmed)
        }
    }

    func renameDailyGroup(id: UUID, title: String) {
        guard !title.trimmed.isEmpty else { return }
        performAndReload {
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

    func addDailyTask(groupID: UUID, title: String) {
        guard !title.trimmed.isEmpty else { return }
        performAndReload {
            _ = try store.addDailyTask(groupID: groupID, title: title.trimmed)
        }
    }

    func renameDailyTask(id: UUID, title: String) {
        guard !title.trimmed.isEmpty else { return }
        performAndReload {
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

    func addLongTermArea(title: String) {
        guard !title.trimmed.isEmpty else { return }
        performAndReload {
            _ = try store.addLongTermArea(title: title.trimmed)
        }
    }

    func renameLongTermArea(id: UUID, title: String) {
        guard !title.trimmed.isEmpty else { return }
        performAndReload {
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

    func addLongTermItem(areaID: UUID, title: String) {
        guard !title.trimmed.isEmpty else { return }
        performAndReload {
            _ = try store.addLongTermItem(areaID: areaID, title: title.trimmed)
        }
    }

    func renameLongTermItem(id: UUID, title: String) {
        guard !title.trimmed.isEmpty else { return }
        performAndReload {
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
        do {
            archiveSearchResults = try store.searchArchives(query: query)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveSettings() {
        do {
            try store.saveSettings(settings)
            settings = try store.loadSettings()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performAndReload(_ operation: () throws -> Void) {
        do {
            try operation()
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
