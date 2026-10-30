import Foundation
import Testing
@testable import NextUpCore

private var calendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "America/Chicago")!
    return cal
}
private func date(_ day: Int, hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
}

@Test func urgentStudyBeatsUntouchedProjectTarget() {
    var data = AppData()
    let study = WorkTask(title: "Prepare for exam", remainingMinutes: 120, due: date(31))
    let project = WorkTask(title: "Ship project feature", area: .project, remainingMinutes: 30, priority: 3)
    data.tasks = [project, study]
    let ranked = Planner.ranked(data, available: 30, energy: .medium, now: date(30), calendar: calendar)
    #expect(ranked.first?.id == study.id)
    #expect(ranked.first?.minutes == 30)
    #expect(ranked.first?.reasons.contains("Due tomorrow.") == true)
}

@Test func weeklyProjectTimeGetsProtectedWhenStudyTargetIsMet() {
    var data = AppData()
    let study = WorkTask(title: "Optional review", remainingMinutes: 30)
    let project = WorkTask(title: "Build feature", area: .project, remainingMinutes: 30)
    data.tasks = [study, project]
    data.sessions = [.init(taskID: study.id, title: study.title, area: .study, startedAt: date(29, hour: 1),
                           endedAt: date(29, hour: 11), seconds: 600 * 60, outcome: .progress, note: "")]
    #expect(Planner.ranked(data, available: 30, energy: .medium, now: date(30), calendar: calendar).first?.id == project.id)
}

@Test func excludedBlockedCompleteAndTooDemandingTasksNeverAppear() {
    var data = AppData()
    let skipped = WorkTask(title: "Skipped", energy: .low)
    data.tasks = [
        WorkTask(title: "Blocked", energy: .low, isBlocked: true),
        WorkTask(title: "Done", energy: .low, isComplete: true),
        WorkTask(title: "Demanding", energy: .high), skipped
    ]
    #expect(Planner.ranked(data, available: 15, energy: .low, excluding: [skipped.id]).isEmpty)
    #expect(Planner.ranked(data, available: 0, energy: .high).isEmpty)
}

@Test func longerTasksGetAUsefulChunkAndShortTasksDoNotOverrun() {
    var data = AppData()
    data.tasks = [.init(title: "Long", remainingMinutes: 90), .init(title: "Short", remainingMinutes: 10)]
    let ranked = Planner.ranked(data, available: 30, energy: .medium)
    #expect(ranked.first { $0.task.title == "Long" }?.minutes == 30)
    #expect(ranked.first { $0.task.title == "Short" }?.minutes == 10)
}

@Test func deadlineUsesLocalDayRatherThanMidnightInstant() {
    var data = AppData()
    data.tasks = [.init(title: "Due today", due: date(30, hour: 0))]
    let rec = Planner.ranked(data, available: 30, energy: .medium, now: date(30, hour: 23), calendar: calendar).first
    #expect(rec?.reasons.first == "Due today.")
}

@Test func weekStartsMondayAndExcludesOldOrFutureSessions() {
    var data = AppData()
    let id = UUID()
    for day in [25, 26, 30, 31] {
        data.sessions.append(.init(taskID: id, title: "Session", area: .project, startedAt: date(day, hour: 8),
                                   endedAt: date(day, hour: 9), seconds: 600, outcome: .progress, note: ""))
    }
    #expect(Planner.weekStart(at: date(30), calendar: calendar) == date(26, hour: 0))
    #expect(Planner.secondsThisWeek(data, area: .project, now: date(30), calendar: calendar) == 1200)
    #expect(Planner.secondsThisWeek(data, area: .study, now: date(30), calendar: calendar) == 0)
}

@Test func pausedTimeDoesNotCountAndResumeIsIdempotent() {
    let now = date(30)
    var active = ActiveSession(task: .init(title: "Work"), targetMinutes: 30, now: now)
    active.pause(at: now.addingTimeInterval(90))
    #expect(active.elapsed(at: now.addingTimeInterval(600)) == 90)
    active.resume(at: now.addingTimeInterval(600))
    active.resume(at: now.addingTimeInterval(610))
    #expect(active.elapsed(at: now.addingTimeInterval(630)) == 120)
    active.pause(at: now.addingTimeInterval(630))
    active.pause(at: now.addingTimeInterval(700))
    #expect(active.accumulatedSeconds == 120)
}

@Test func dataRoundTripsWithoutLosingAnActiveSessionOrHistory() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = DataRepository(url: directory.appendingPathComponent("data.json"))
    #expect(try repository.load() == AppData())
    var data = AppData()
    let task = WorkTask(title: "Saved task", nextAction: "Continue here")
    data.tasks = [task]
    data.active = ActiveSession(task: task, targetMinutes: 30, now: date(30))
    data.sessions = [.init(taskID: UUID(), title: "Deleted task", area: .career, startedAt: date(29, hour: 8),
                           endedAt: date(29, hour: 9), seconds: 60, outcome: .complete, note: "Saved note")]
    try repository.save(data)
    #expect(try repository.load() == data)
}

@Test func invalidDataIsRejectedAndCorruptFileIsPreserved() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("data.json")
    let bytes = Data("not json".utf8)
    try bytes.write(to: url)
    #expect(throws: (any Error).self) { try DataRepository(url: url).load() }
    #expect(try Data(contentsOf: url) == bytes)
    var invalid = AppData()
    invalid.tasks = [.init(title: "Invalid", remainingMinutes: -1)]
    #expect(throws: (any Error).self) { try DataRepository(url: url).save(invalid) }
    #expect(try Data(contentsOf: url) == bytes)
}

@Test func unsupportedSchemaAndOrphanActiveSessionAreRejected() {
    var data = AppData()
    data.version = 2
    #expect(throws: DataError.self) { try data.validate() }
    data.version = 1
    data.active = ActiveSession(task: .init(title: "Missing"), targetMinutes: 30)
    #expect(throws: DataError.self) { try data.validate() }
}
