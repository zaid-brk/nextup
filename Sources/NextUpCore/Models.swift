import Foundation

public enum Area: String, Codable, CaseIterable, Identifiable, Sendable {
    case study = "Study", project = "Projects", career = "Career", personal = "Personal"
    public var id: String { rawValue }
    public var symbol: String {
        switch self {
        case .study: "book.closed"
        case .project: "hammer"
        case .career: "briefcase"
        case .personal: "leaf"
        }
    }
}

public enum Energy: Int, Codable, CaseIterable, Identifiable, Sendable {
    case low = 1, medium, high
    public var id: Int { rawValue }
    public var label: String {
        switch self { case .low: "Low"; case .medium: "Medium"; case .high: "High" }
    }
}

public struct WorkTask: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var area: Area
    public var context: String
    public var remainingMinutes: Int
    public var energy: Energy
    public var priority: Int
    public var due: Date?
    public var finishLine: String
    public var nextAction: String
    public var isComplete: Bool
    public var isBlocked: Bool
    public var createdAt: Date

    public init(id: UUID = UUID(), title: String, area: Area = .study,
                context: String = "", remainingMinutes: Int = 30, energy: Energy = .medium,
                priority: Int = 2, due: Date? = nil, finishLine: String = "", nextAction: String = "",
                isComplete: Bool = false, isBlocked: Bool = false, createdAt: Date = Date()) {
        self.id = id; self.title = title; self.area = area; self.context = context
        self.remainingMinutes = remainingMinutes; self.energy = energy; self.priority = priority
        self.due = due; self.finishLine = finishLine; self.nextAction = nextAction
        self.isComplete = isComplete; self.isBlocked = isBlocked; self.createdAt = createdAt
    }
}

public enum Outcome: String, Codable, CaseIterable, Identifiable, Sendable {
    case progress = "Made progress", complete = "Finished task", blocked = "Got blocked"
    public var id: String { rawValue }
}

public struct FocusSession: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var taskID: UUID
    public var title: String
    public var area: Area
    public var startedAt: Date
    public var endedAt: Date
    public var seconds: Int
    public var outcome: Outcome
    public var note: String
    public init(taskID: UUID, title: String, area: Area, startedAt: Date, endedAt: Date,
                seconds: Int, outcome: Outcome, note: String) {
        self.taskID = taskID; self.title = title; self.area = area; self.startedAt = startedAt
        self.endedAt = endedAt; self.seconds = seconds; self.outcome = outcome; self.note = note
    }
}

public struct ActiveSession: Codable, Equatable, Sendable {
    public var taskID: UUID
    public var title: String
    public var area: Area
    public var targetMinutes: Int
    public var startedAt: Date
    public var runningSince: Date?
    public var accumulatedSeconds: Int = 0

    public init(task: WorkTask, targetMinutes: Int, now: Date = Date()) {
        taskID = task.id; title = task.title; area = task.area
        self.targetMinutes = targetMinutes; startedAt = now; runningSince = now
    }
    public func elapsed(at now: Date) -> Int {
        accumulatedSeconds + max(0, Int(runningSince.map { now.timeIntervalSince($0) } ?? 0))
    }
    public mutating func pause(at now: Date) {
        accumulatedSeconds = elapsed(at: now); runningSince = nil
    }
    public mutating func resume(at now: Date) {
        if runningSince == nil { runningSince = now }
    }
}

public struct WeeklyTarget: Codable, Equatable, Sendable {
    public var area: Area
    public var minutes: Int
    public init(area: Area, minutes: Int) { self.area = area; self.minutes = minutes }
}

public struct AppData: Codable, Equatable, Sendable {
    public var version: Int = 1
    public var tasks: [WorkTask] = []
    public var sessions: [FocusSession] = []
    public var targets: [WeeklyTarget] = [
        .init(area: .study, minutes: 600), .init(area: .project, minutes: 240),
        .init(area: .career, minutes: 60), .init(area: .personal, minutes: 60)
    ]
    public var active: ActiveSession?
    public init() {}

    public func validate() throws {
        guard version == 1,
              Set(tasks.map(\.id)).count == tasks.count,
              Set(sessions.map(\.id)).count == sessions.count,
              Set(targets.map(\.area)).count == Area.allCases.count,
              targets.count == Area.allCases.count,
              tasks.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && (1...10_000).contains($0.remainingMinutes) && (1...3).contains($0.priority) }),
              targets.allSatisfy({ (0...10_080).contains($0.minutes) }),
              sessions.allSatisfy({ $0.seconds >= 0 && $0.endedAt >= $0.startedAt })
        else { throw DataError.invalid }
        if let active {
            guard tasks.contains(where: { $0.id == active.taskID && !$0.isComplete && !$0.isBlocked }),
                  (1...240).contains(active.targetMinutes), active.accumulatedSeconds >= 0
            else { throw DataError.invalid }
        }
    }
}

public enum DataError: LocalizedError {
    case invalid
    public var errorDescription: String? { "The saved data is invalid or from an unsupported version. Your original file has not been changed." }
}
