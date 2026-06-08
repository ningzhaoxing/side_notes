import Foundation

public enum TriggerSide: String, Codable, Equatable, Sendable {
    case left
    case right
}

public enum VisibleSide: String, Codable, Equatable, Sendable {
    case front
    case back
}

public struct StoredRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }

    public func intersects(_ other: StoredRect) -> Bool {
        maxX > other.x && other.maxX > x && maxY > other.y && other.maxY > y
    }
}

public struct DailyTask: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        sortOrder: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct DailyPlanGroup: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var sortOrder: Int
    public var tasks: [DailyTask]

    public init(id: UUID = UUID(), title: String, sortOrder: Int, tasks: [DailyTask] = []) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.tasks = tasks
    }
}

public struct DailyPlan: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var planningDate: Date
    public var groups: [DailyPlanGroup]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        planningDate: Date = Date(),
        groups: [DailyPlanGroup] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.planningDate = planningDate
        self.groups = groups
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ArchiveDay: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var archiveDate: Date
    public var sourcePlanningDate: Date
    public var groupsSnapshot: [DailyPlanGroup]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        archiveDate: Date,
        sourcePlanningDate: Date,
        groupsSnapshot: [DailyPlanGroup],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.archiveDate = archiveDate
        self.sourcePlanningDate = sourcePlanningDate
        self.groupsSnapshot = groupsSnapshot
        self.createdAt = createdAt
    }
}

public struct LongTermItem: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        sortOrder: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct LongTermArea: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var sortOrder: Int
    public var items: [LongTermItem]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        sortOrder: Int,
        items: [LongTermItem] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.items = items
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var triggerSide: TriggerSide
    public var isPinned: Bool
    public var cardFrame: StoredRect
    public var editorFrame: StoredRect
    public var visibleSide: VisibleSide
    public var cardOpacity: Double
    public var cardCornerRadius: Double
    public var lastArchiveDate: Date?

    public init(
        triggerSide: TriggerSide,
        isPinned: Bool,
        cardFrame: StoredRect,
        editorFrame: StoredRect,
        visibleSide: VisibleSide,
        cardOpacity: Double,
        cardCornerRadius: Double,
        lastArchiveDate: Date?
    ) {
        self.triggerSide = triggerSide
        self.isPinned = isPinned
        self.cardFrame = cardFrame
        self.editorFrame = editorFrame
        self.visibleSide = visibleSide
        self.cardOpacity = cardOpacity
        self.cardCornerRadius = cardCornerRadius
        self.lastArchiveDate = lastArchiveDate
    }

    public static func defaults() -> AppSettings {
        AppSettings(
            triggerSide: .right,
            isPinned: true,
            cardFrame: StoredRect(x: 1_088, y: 160, width: 320, height: 580),
            editorFrame: StoredRect(x: 220, y: 140, width: 920, height: 680),
            visibleSide: .front,
            cardOpacity: 0.94,
            cardCornerRadius: 22,
            lastArchiveDate: nil
        )
    }

    public mutating func validate(visibleFrames: [StoredRect] = []) {
        cardOpacity = min(1, max(0.35, cardOpacity))
        cardCornerRadius = min(48, max(4, cardCornerRadius))
        cardFrame.width = min(720, max(260, cardFrame.width))
        cardFrame.height = min(900, max(360, cardFrame.height))

        guard !visibleFrames.isEmpty else {
            return
        }

        if !visibleFrames.contains(where: { cardFrame.intersects($0) }) {
            let frame = visibleFrames[0]
            let defaultFrame = AppSettings.defaults().cardFrame
            cardFrame = StoredRect(
                x: frame.maxX - defaultFrame.width - 32,
                y: frame.y + max(24, (frame.height - defaultFrame.height) / 2),
                width: defaultFrame.width,
                height: defaultFrame.height
            )
        }
    }
}
