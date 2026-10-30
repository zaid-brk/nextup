import SwiftUI
import NextUpCore

struct WeekView: View {
    @EnvironmentObject var store: Store
    @State private var editingTargets = false
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Make space for what matters.").font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text("A weekly direction, with room for life. Resets every Monday.")
                        .font(.system(size: 14)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Button("Edit targets") { editingTargets = true }.buttonStyle(SoftButton())
            }
            HStack(spacing: 18) {
                metric("FOCUSED TIME", durationLabel(Planner.secondsThisWeek(store.data) / 60), "From your logged sessions")
                metric("WEEKLY TARGET", durationLabel(store.data.targets.reduce(0) { $0 + $1.minutes }), "A guide, not a quota")
            }
            VStack(alignment: .leading, spacing: 24) {
                Text("YOUR BALANCE").eyebrow()
                ForEach(Area.allCases) { area in
                    let target = store.data.targets.first { $0.area == area }?.minutes ?? 0
                    let seconds = Planner.secondsThisWeek(store.data, area: area)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label(area.rawValue, systemImage: area.symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.tint(area))
                            Spacer()
                            Text(target == 0 ? "\(durationLabel(seconds / 60)) · no target" : "\(durationLabel(seconds / 60)) / \(durationLabel(target))")
                                .font(.system(size: 12)).foregroundStyle(Theme.muted)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.tint(area).opacity(0.08))
                                Capsule().fill(Theme.tint(area)).frame(width: target > 0 ? geo.size.width * min(1, Double(seconds) / Double(target * 60)) : 0)
                            }
                        }.frame(height: 7)
                    }
                }
            }.card()
            VStack(alignment: .leading, spacing: 12) {
                Label("How your targets affect recommendations", systemImage: "info.circle").font(.system(size: 14, weight: .semibold))
                Text("Areas with time left in their target get a boost. Urgent deadlines still take priority. Targets never block you from working on an area, and unfinished time does not roll into next week.")
                    .font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(5)
                Text("Start with hours you can realistically protect after classes, sleep, meals, and breaks. Set a target to zero to remove its weekly boost.")
                    .font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(5)
            }.card()
        }.sheet(isPresented: $editingTargets) { TargetEditor() }
    }
    private func metric(_ title: String, _ value: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).eyebrow()
            Text(value).font(.system(size: 30, weight: .semibold, design: .rounded))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.muted)
        }.card()
    }
}

struct TargetEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var targets: [WeeklyTarget] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("A week that fits your life.").font(.system(size: 25, weight: .semibold, design: .rounded))
            Text("Starting suggestions only. Adjust these to your real availability.")
                .font(.system(size: 13)).foregroundStyle(Theme.muted)
            ForEach(targets.indices, id: \.self) { i in
                HStack {
                    AreaBadge(area: targets[i].area)
                    Spacer()
                    Stepper(durationLabel(targets[i].minutes), value: $targets[i].minutes, in: 0...10_080, step: 30)
                        .frame(width: 160)
                }
            }
            Text("Total: \(durationLabel(targets.reduce(0) { $0 + $1.minutes })) per week")
                .font(.system(size: 14, weight: .semibold))
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SoftButton())
                Button("Save targets") { if store.change({ $0.targets = targets }) { dismiss() } }
                    .buttonStyle(PrimaryButton()).keyboardShortcut(.defaultAction)
            }
        }.padding(30).frame(width: 500).onAppear { targets = store.data.targets }
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Small steps add up.").font(.system(size: 32, weight: .semibold, design: .rounded))
                Text("A record of what you actually moved forward.").foregroundStyle(Theme.muted)
            }
            if store.data.sessions.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "clock").font(.system(size: 28)).foregroundStyle(Theme.purple)
                    Text("Your first session starts a story.").font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("Start a focus session from Right now. When you finish, the result and your next action will appear here.")
                        .font(.system(size: 14)).foregroundStyle(Theme.muted)
                }.card()
            }
            ForEach(store.data.sessions.sorted { $0.endedAt > $1.endedAt }) { session in
                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        AreaBadge(area: session.area)
                        Text(session.outcome.rawValue).font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text(durationLabel(session.seconds / 60)).font(.system(size: 13, weight: .semibold))
                    }
                    Text(session.title).font(.system(size: 17, weight: .semibold))
                    if !session.note.isEmpty { Text(session.note).font(.system(size: 13)).foregroundStyle(Theme.muted) }
                    Text(session.endedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.system(size: 11)).foregroundStyle(Theme.muted)
                }.card()
            }
        }
    }
}
