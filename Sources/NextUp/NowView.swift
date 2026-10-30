import SwiftUI
import NextUpCore

struct NowView: View {
    @EnvironmentObject var store: Store
    var addTask: () -> Void
    var editTask: (WorkTask) -> Void
    @State private var available = 30
    @State private var energy: Energy = .medium
    @State private var skipped: Set<UUID> = []
    @State private var finishSheet = false
    @State private var exampleConfirmation = false

    private var recommendations: [Recommendation] {
        Planner.ranked(store.data, available: available, energy: energy, excluding: skipped)
    }
    private var openTasks: [WorkTask] { store.data.tasks.filter { !$0.isComplete } }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 9) {
                Text(store.data.active == nil ? "One thing at a time." : "You’ve made room to focus.")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                Text(store.data.active == nil ? "Choose the moment. We’ll help you choose the work." : "Stay with this task. Everything else can wait.")
                    .font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            if let active = store.data.active {
                activeCard(active)
            } else if store.data.tasks.isEmpty {
                welcome
            } else {
                controls
                if let rec = recommendations.first {
                    recommendationCard(rec)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: "sun.horizon").font(.system(size: 28)).foregroundStyle(Theme.purple)
                        Text(openTasks.isEmpty ? "You’ve cleared your list." : "Nothing matches this moment.").font(.title2.bold())
                        Text(openTasks.isEmpty ? "Take a break, or add your next meaningful task." : "Your tasks may need more energy, be blocked, or have been skipped. It’s okay to take a break too.")
                            .foregroundStyle(Theme.muted)
                        HStack {
                            if !skipped.isEmpty { Button("Show skipped tasks") { skipped.removeAll() }.buttonStyle(SoftButton()) }
                            Button("Add a task", action: addTask).buttonStyle(PrimaryButton())
                        }
                    }.card()
                }
            }
            weekSnapshot
        }
        .onChange(of: available) { _, _ in skipped.removeAll() }
        .onChange(of: energy) { _, _ in skipped.removeAll() }
        .sheet(isPresented: $finishSheet) { FinishSessionView() }
        .confirmationDialog("Add three clearly labeled example tasks? You can edit or delete them anytime.", isPresented: $exampleConfirmation) {
            Button("Add example tasks") { store.loadExamples() }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Image(systemName: "sparkle").font(.system(size: 28)).foregroundStyle(Theme.purple)
                Spacer()
                Text("LET’S GET YOU STARTED").eyebrow()
            }
            Text("Less deciding. More doing.").font(.system(size: 26, weight: .semibold, design: .rounded))
            Text("Add a few things you want to move forward. Include deadlines and a clear finish line. Next Up will suggest a useful step whenever you have time.")
                .font(.system(size: 14)).foregroundStyle(Theme.muted).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 26) {
                setupStep("01", "Capture the work", "An assignment, a project feature, or something personal.")
                setupStep("02", "Set a weekly balance", "Adjust the starting targets in This week to fit your schedule.")
                setupStep("03", "Pick your moment", "Tell us your time and energy. Get one next action.")
            }.padding(.vertical, 5)
            HStack(spacing: 16) {
                Button(action: addTask) { Label("Add your first task", systemImage: "plus") }.buttonStyle(PrimaryButton())
                Button("Try example tasks") { exampleConfirmation = true }.buttonStyle(.plain).foregroundStyle(Theme.muted)
            }
        }.card()
    }

    private func setupStep(_ number: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(number).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Theme.purple)
            Text(title).font(.system(size: 13, weight: .semibold))
            Text(detail).font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(3)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        HStack(alignment: .top, spacing: 30) {
            VStack(alignment: .leading, spacing: 12) {
                Text("TIME AVAILABLE").eyebrow()
                HStack(spacing: 6) {
                    ForEach([15, 30, 45, 60, 90], id: \.self) { value in
                        Button { available = value } label: {
                            Text("\(value)m").font(.system(size: 13, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 9)
                                .foregroundStyle(available == value ? .white : Theme.ink)
                                .background(available == value ? Theme.ink : Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 12) {
                Text("YOUR ENERGY").eyebrow()
                Picker("Your energy", selection: $energy) {
                    ForEach(Energy.allCases) { Text($0.label).tag($0) }
                }.labelsHidden().pickerStyle(.segmented).frame(width: 220)
                    .padding(.top, 3)
            }
        }.card()
    }

    private func recommendationCard(_ rec: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("YOUR NEXT GOOD STEP", systemImage: "sparkle").eyebrow()
                Spacer()
                Text("\(rec.minutes) MIN FOCUS").font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.purple)
            }
            HStack(spacing: 8) {
                AreaBadge(area: rec.task.area)
                if !rec.task.context.isEmpty { Text(rec.task.context).font(.system(size: 12)).foregroundStyle(Theme.muted) }
            }
            Text(rec.task.title).font(.system(size: 27, weight: .semibold, design: .rounded)).fixedSize(horizontal: false, vertical: true)
            if !rec.task.nextAction.isEmpty {
                Text(rec.task.nextAction).font(.system(size: 14)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 9) {
                Text("WHY THIS, NOW").eyebrow()
                ForEach(rec.reasons, id: \.self) { reason in
                    Label(reason, systemImage: "checkmark").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
            }
            if !rec.task.finishLine.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("TASK FINISH LINE").eyebrow()
                    Text(rec.task.finishLine).font(.system(size: 13)).lineSpacing(3)
                }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 10))
            }
            HStack(spacing: 14) {
                Button { store.start(rec) } label: { Label("Start \(rec.minutes)-minute session", systemImage: "play.fill") }
                    .buttonStyle(PrimaryButton())
                Button("Something else") { skipped.insert(rec.id) }.buttonStyle(SoftButton())
                Spacer()
                Button { editTask(rec.task) } label: { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(.plain).help("Correct this task’s estimate, energy, or priority")
            }
        }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.purple.opacity(0.24), lineWidth: 1))
    }

    private func activeCard(_ active: ActiveSession) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = active.elapsed(at: context.date)
            let remaining = max(0, active.targetMinutes * 60 - elapsed)
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    AreaBadge(area: active.area)
                    Spacer()
                    Text(active.runningSince == nil ? "PAUSED" : remaining == 0 ? "READY TO WRAP UP" : "FOCUS SESSION").eyebrow()
                }
                Text(active.title).font(.system(size: 26, weight: .semibold, design: .rounded))
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                        .font(.system(size: 72, weight: .light, design: .rounded)).monospacedDigit()
                    Text("remaining").font(.system(size: 14)).foregroundStyle(Theme.muted)
                }
                ProgressView(value: min(Double(elapsed) / Double(active.targetMinutes * 60), 1)).tint(Theme.purple)
                Text(remaining == 0 ? "Your planned time is up. Wrap up when you’re ready; you can correct the logged time below." : "A small, focused step is enough. Pause whenever you need to.")
                    .font(.system(size: 13)).foregroundStyle(Theme.muted)
                HStack {
                    Button(active.runningSince == nil ? "Resume" : "Pause") {
                        if active.runningSince == nil { store.resume() } else { store.pause() }
                    }.buttonStyle(SoftButton())
                    Button("Finish session") { store.pause(); finishSheet = true }.buttonStyle(PrimaryButton())
                    Spacer()
                    Text("\(elapsed / 60)m elapsed").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
            }.card()
        }
    }

    private var weekSnapshot: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("THIS WEEK").eyebrow()
                Text("\(durationLabel(Planner.secondsThisWeek(store.data) / 60)) focused")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            Spacer()
            Text("\(store.data.sessions.filter { $0.endedAt >= Planner.weekStart(at: .now) && $0.outcome == .complete }.count) tasks finished")
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
            Divider().frame(height: 28)
            Text("Progress counts. Breaks belong.").font(.system(size: 12)).foregroundStyle(Theme.muted)
        }.padding(.vertical, 8)
    }
}

struct FinishSessionView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var outcome: Outcome = .progress
    @State private var note = ""
    @State private var minutes = 0
    @State private var discard = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("A step forward.").font(.system(size: 27, weight: .semibold, design: .rounded))
            Text(store.data.active?.title ?? "Session").foregroundStyle(Theme.muted)
            Picker("How did it go?", selection: $outcome) {
                ForEach(Outcome.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            Stepper("Focused time: \(durationLabel(minutes))", value: $minutes, in: 0...1440, step: 1)
            Text("Adjust this if you stepped away. Only this time is added to your weekly totals.")
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
            Text(outcome == .blocked ? "What’s blocking you?" : outcome == .complete ? "Anything to remember?" : "Leave yourself a next action")
                .font(.system(size: 13, weight: .semibold))
            TextField("A specific note for your next session…", text: $note, axis: .vertical)
                .lineLimit(3...5).textFieldStyle(.roundedBorder)
            if outcome == .blocked {
                Text("This task will stay out of recommendations until you unblock it in Tasks.")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            HStack {
                Button("Discard session", role: .destructive) { discard = true }.buttonStyle(.plain).foregroundStyle(.red)
                Spacer()
                Button("Back") { dismiss() }.buttonStyle(SoftButton())
                Button("Save session") {
                    if store.finish(outcome: outcome, note: note, minutes: minutes) { dismiss() }
                }.buttonStyle(PrimaryButton()).keyboardShortcut(.defaultAction)
            }
        }.padding(30).frame(width: 540)
            .onAppear { minutes = min(1440, (store.data.active?.elapsed(at: Date()) ?? 0) / 60) }
            .confirmationDialog("Discard this session? No time or progress will be logged.", isPresented: $discard) {
                Button("Discard session", role: .destructive) { if store.change({ $0.active = nil }) { dismiss() } }
            }
    }
}
