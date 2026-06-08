import Foundation

public struct ArchiveResult: Equatable, Sendable {
    public var current: DailyPlan
    public var archives: [ArchiveDay]

    public init(current: DailyPlan, archives: [ArchiveDay]) {
        self.current = current
        self.archives = archives
    }
}

public enum ArchiveService {
    public static func archive(
        plan: DailyPlan,
        existingArchives: [ArchiveDay],
        now: Date = Date()
    ) -> ArchiveResult {
        let sortedSnapshot = plan.groups
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { group in
                var copy = group
                copy.tasks = group.tasks.sorted { $0.sortOrder < $1.sortOrder }
                return copy
            }

        let archive = ArchiveDay(
            archiveDate: now,
            sourcePlanningDate: plan.planningDate,
            groupsSnapshot: sortedSnapshot,
            createdAt: now
        )

        let newCurrent = DailyPlan(
            planningDate: now,
            groups: [],
            createdAt: now,
            updatedAt: now
        )

        return ArchiveResult(current: newCurrent, archives: existingArchives + [archive])
    }
}
