import SwiftUI
import NextUpCore

struct WeekView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 18) {
                metric("FOCUSED TIME", durationLabel(Planner.secondsThisWeek(store.data) / 60))
                metric("WEEKLY TARGET", durationLabel(store.data.targets.reduce(0) { $0 + $1.minutes }))
            }
            VStack(alignment: .leading, spacing: 24) {
                Text("TIME BY AREA").eyebrow()
                ForEach(Area.allCases) { area in
                    let target = store.data.targets.first { $0.area == area }?.minutes ?? 0
                    let seconds = Planner.secondsThisWeek(store.data, area: area)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(area.rawValue).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.tint(area))
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
            Text("Weeks start Monday. Totals include saved sessions only.")
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
    }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).eyebrow()
            Text(value).font(.system(size: 30, weight: .semibold, design: .rounded))
        }.card()
    }
}

struct TargetEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var targets: [WeeklyTarget] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Weekly targets").font(.system(size: 24, weight: .semibold))
            Text("Areas below target get higher recommendation priority. Set a target to 0 to disable its boost.")
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
            if store.data.sessions.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("No sessions").font(.system(size: 20, weight: .semibold))
                    Text("Start and finish a session in Right now to log time.")
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
