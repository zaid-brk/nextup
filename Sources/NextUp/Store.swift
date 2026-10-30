import AppKit
import SwiftUI
import Combine
import NextUpCore

@MainActor
final class Store: ObservableObject {
    @Published private(set) var data = AppData()
    @Published var error: String?
    @Published private(set) var loadFailed = false
    let repository: DataRepository

    init() {
        let directory = ProcessInfo.processInfo.environment["NEXTUP_DATA_DIR"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("NextUp", isDirectory: true)
        repository = DataRepository(url: directory.appendingPathComponent("data.json"))
        reload()
        // An interrupted session is restored paused: time while the app was closed is never logged.
        if var active = data.active {
            active.runningSince = nil
            change { $0.active = active }
        }
    }

    func reload() {
        do { data = try repository.load(); loadFailed = false }
        catch { loadFailed = true; self.error = "Could not read your data. \(error.localizedDescription) Use Show data folder to recover the file, then Retry loading. Saving is disabled until it loads successfully." }
    }

    @discardableResult
    func change(_ edit: (inout AppData) -> Void) -> Bool {
        guard !loadFailed else { return false }
        var updated = data; edit(&updated)
        do { try repository.save(updated); data = updated; return true }
        catch { self.error = "Could not save. The change was not applied. \(error.localizedDescription)"; return false }
    }

    func upsert(_ task: WorkTask) -> Bool {
        change { state in
            if let i = state.tasks.firstIndex(where: { $0.id == task.id }) { state.tasks[i] = task }
            else { state.tasks.append(task) }
        }
    }

    func start(_ rec: Recommendation) {
        guard data.active == nil else { return }
        change { $0.active = ActiveSession(task: rec.task, targetMinutes: rec.minutes) }
    }
    func pause() {
        change { $0.active?.pause(at: Date()) }
    }
    func resume() {
        change { $0.active?.resume(at: Date()) }
    }
    func checkpoint() {
        guard var active = data.active, active.runningSince != nil else { return }
        let now = Date(); active.pause(at: now); active.resume(at: now)
        change { $0.active = active }
    }

    func finish(outcome: Outcome, note: String, minutes: Int) -> Bool {
        guard let active = data.active else { return false }
        return change { state in
            state.sessions.insert(FocusSession(taskID: active.taskID, title: active.title, area: active.area,
                startedAt: active.startedAt, endedAt: Date(), seconds: minutes * 60, outcome: outcome, note: note), at: 0)
            if let i = state.tasks.firstIndex(where: { $0.id == active.taskID }) {
                state.tasks[i].remainingMinutes = max(1, state.tasks[i].remainingMinutes - minutes)
                state.tasks[i].isComplete = outcome == .complete
                state.tasks[i].isBlocked = outcome == .blocked
                if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { state.tasks[i].nextAction = note }
            }
            state.active = nil
        }
    }

    func showDataFolder() {
        try? FileManager.default.createDirectory(at: repository.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        NSWorkspace.shared.open(repository.url.deletingLastPathComponent())
    }

    func exportBackup() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "NextUp-backup.json"
        panel.title = "Export your Next Up data"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try DataRepository(url: url).save(data) }
        catch { self.error = "Could not export backup: \(error.localizedDescription)" }
    }

    func loadExamples() {
        guard data.tasks.isEmpty && data.sessions.isEmpty else { return }
        change { state in
            state.tasks = [
                WorkTask(title: "Practice processes and file descriptors", area: .study, context: "Example • Operating systems",
                         remainingMinutes: 45, energy: .high, priority: 3, due: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
                         finishLine: "Solve three problems and explain each answer without notes.", nextAction: "Open the practice set and attempt problem one."),
                WorkTask(title: "Build the empty state for my project", area: .project, context: "Example • Personal project",
                         remainingMinutes: 60, energy: .medium, finishLine: "An empty list shows a helpful message and an add button.",
                         nextAction: "Sketch the empty state, then implement the component."),
                WorkTask(title: "Prepare one interview story", area: .career, context: "Example • Interview preparation",
                         remainingMinutes: 20, energy: .low, finishLine: "A one-minute story with a specific problem, action, and result.")
            ]
        }
    }
}
