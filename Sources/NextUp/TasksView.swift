import SwiftUI
import NextUpCore

struct TasksView: View {
    @EnvironmentObject var store: Store
    var editTask: (WorkTask) -> Void
    var addTask: () -> Void
    @State private var search = ""
    @State private var filter = "Open"
    @State private var deletion: WorkTask?
    private var filtered: [WorkTask] {
        store.data.tasks.filter { task in
            (filter == "All" || (filter == "Completed" ? task.isComplete : !task.isComplete)) &&
            (search.isEmpty || "\(task.title) \(task.context) \(task.area.rawValue)".localizedCaseInsensitiveContains(search))
        }.sorted {
            if $0.isComplete != $1.isComplete { return !$0.isComplete }
            if $0.due != $1.due { return ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
            return $0.createdAt < $1.createdAt
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Give your work a place.").font(.system(size: 32, weight: .semibold, design: .rounded))
                Text("Small enough to start. Clear enough to finish.").foregroundStyle(Theme.muted)
            }
            HStack {
                TextField("Search tasks or courses", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 330)
                Spacer()
                Picker("Task status", selection: $filter) {
                    ForEach(["Open", "Completed", "All"], id: \.self) { Text($0).tag($0) }
                }.labelsHidden().pickerStyle(.segmented).frame(width: 235)
            }
            if filtered.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Nothing here yet.").font(.title2.bold())
                    Text(search.isEmpty ? "Add a task you want to move forward." : "Try another search or status filter.").foregroundStyle(Theme.muted)
                    Button("Add task", action: addTask).buttonStyle(PrimaryButton())
                }.card()
            }
            ForEach(filtered) { task in
                HStack(alignment: .top, spacing: 14) {
                    Button {
                        store.change { state in
                            if let i = state.tasks.firstIndex(where: { $0.id == task.id }) {
                                state.tasks[i].isComplete.toggle()
                                if state.tasks[i].isComplete { state.tasks[i].isBlocked = false }
                            }
                        }
                    } label: {
                        Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 23)).foregroundStyle(task.isComplete ? Theme.purple : Theme.muted.opacity(0.5))
                    }.buttonStyle(.plain).disabled(store.data.active?.taskID == task.id)
                        .help("Mark complete or reopen; only focus sessions add logged time")
                    VStack(alignment: .leading, spacing: 9) {
                        Button { editTask(task) } label: {
                            Text(task.title).font(.system(size: 16, weight: .semibold)).multilineTextAlignment(.leading)
                                .strikethrough(task.isComplete).foregroundStyle(Theme.ink)
                        }.buttonStyle(.plain).disabled(store.data.active?.taskID == task.id)
                        HStack(spacing: 9) {
                            AreaBadge(area: task.area)
                            if !task.context.isEmpty { Text(task.context).font(.system(size: 11)).foregroundStyle(Theme.muted) }
                            Text("· \(durationLabel(task.remainingMinutes)) · \(task.energy.label) energy")
                                .font(.system(size: 11)).foregroundStyle(Theme.muted)
                        }
                        if let due = task.due {
                            Text("Due \(due.formatted(date: .abbreviated, time: .omitted))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Calendar.current.startOfDay(for: due) < Calendar.current.startOfDay(for: Date()) && !task.isComplete ? .red : Theme.muted)
                        }
                        if task.isBlocked {
                            Label(task.nextAction.isEmpty ? "Blocked" : "Blocked: \(task.nextAction)", systemImage: "pause.circle")
                                .font(.system(size: 12)).foregroundStyle(.orange)
                            Button("Unblock task") { store.change { state in
                                if let i = state.tasks.firstIndex(where: { $0.id == task.id }) { state.tasks[i].isBlocked = false }
                            } }.buttonStyle(SoftButton())
                        }
                        if store.data.active?.taskID == task.id {
                            Text("In progress — finish the session before editing.").font(.system(size: 11)).foregroundStyle(Theme.purple)
                        }
                    }
                    Spacer(minLength: 0)
                    Menu {
                        Button("Edit task") { editTask(task) }
                        Button("Delete task", role: .destructive) { deletion = task }
                    } label: { Image(systemName: "ellipsis") }
                        .menuStyle(.borderlessButton).frame(width: 24).disabled(store.data.active?.taskID == task.id)
                }.card()
            }
        }
        .confirmationDialog("Delete this task? Session history will be kept.", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })) {
            Button("Delete task", role: .destructive) {
                if let deletion { store.change { $0.tasks.removeAll { $0.id == deletion.id } } }
                deletion = nil
            }
        }
    }
}

struct TaskEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var task: WorkTask
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var validation: String?

    private var existing: Bool { store.data.tasks.contains { $0.id == task.id } }
    private var valid: Bool {
        !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (1...10_000).contains(task.remainingMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(existing ? "Make the next step clearer." : "What do you want to move forward?")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Text("Specific tasks make better recommendations.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                Spacer()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    field("TASK") { TextField("e.g. Practice three process synchronization problems", text: $task.title) }
                    HStack(alignment: .top, spacing: 20) {
                        field("AREA") {
                            Picker("Area", selection: $task.area) { ForEach(Area.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden()
                        }
                        field("COURSE OR PROJECT") { TextField("e.g. CSCE 313", text: $task.context) }
                    }
                    HStack(alignment: .top, spacing: 20) {
                        field("TIME REMAINING") {
                            HStack {
                                TextField("Minutes", value: $task.remainingMinutes, format: .number).frame(width: 80)
                                Text("minutes").foregroundStyle(Theme.muted)
                            }
                        }
                        field("ENERGY NEEDED") {
                            Picker("Energy needed", selection: $task.energy) { ForEach(Energy.allCases) { Text($0.label).tag($0) } }.labelsHidden()
                        }
                        field("PRIORITY") {
                            Picker("Priority", selection: $task.priority) {
                                Text("Low").tag(1); Text("Normal").tag(2); Text("High").tag(3)
                            }.labelsHidden()
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Has a deadline", isOn: $hasDeadline).toggleStyle(.switch)
                        if hasDeadline { DatePicker("Due date", selection: $deadline, displayedComponents: .date) }
                    }
                    field("DONE WHEN…") {
                        TextField("e.g. I can explain the answers without checking notes", text: $task.finishLine, axis: .vertical).lineLimit(2...3)
                    }
                    field("FIRST / NEXT ACTION") {
                        TextField("e.g. Open the practice set and attempt problem one", text: $task.nextAction, axis: .vertical).lineLimit(2...3)
                    }
                    if existing && !task.isComplete { Toggle("Blocked — exclude from recommendations", isOn: $task.isBlocked) }
                    Text("Large tasks can span multiple sessions. Keep estimates rough and update them as you learn.")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted)
                }.textFieldStyle(.roundedBorder).padding(2)
            }
            if let validation { Text(validation).font(.system(size: 12)).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SoftButton()).keyboardShortcut(.cancelAction)
                Button(existing ? "Save changes" : "Add task") {
                    task.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    task.due = hasDeadline ? Calendar.current.startOfDay(for: deadline) : nil
                    guard valid else { validation = "Add a task name and an estimate between 1 and 10,000 minutes."; return }
                    guard store.data.active?.taskID != task.id else { validation = "Finish the active session before editing this task."; return }
                    if store.upsert(task) { dismiss() }
                }.buttonStyle(PrimaryButton()).disabled(!valid).keyboardShortcut(.defaultAction)
            }
        }.padding(30).frame(width: 620, height: 660)
            .onAppear { hasDeadline = task.due != nil; deadline = task.due ?? Date() }
    }

    private func field<Content: View>(_ name: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(name).eyebrow(); content() }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
