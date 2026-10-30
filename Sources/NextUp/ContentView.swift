import SwiftUI
import Combine
import NextUpCore

enum Page: String, CaseIterable {
    case now = "Right now", tasks = "Tasks", week = "This week", history = "History"
    var symbol: String {
        switch self { case .now: "sparkle"; case .tasks: "checklist"; case .week: "chart.bar.xaxis"; case .history: "clock.arrow.circlepath" }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @Environment(\.scenePhase) private var phase
    @State private var page: Page = .now
    @State private var editing: WorkTask?
    @State private var showNew = false
    private let checkpoint = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Text(page.rawValue.uppercased()).eyebrow()
                        Spacer()
                        Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                        Button { showNew = true } label: { Label("Add task", systemImage: "plus") }
                            .buttonStyle(SoftButton()).disabled(store.loadFailed)
                    }
                    if store.loadFailed {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Your data needs attention").font(.title2.bold())
                            Text("Saving is paused to protect your original file. Open the data folder to recover it, then retry loading.")
                            HStack {
                                Button("Show data folder") { store.showDataFolder() }
                                Button("Retry loading") { store.reload() }
                            }.buttonStyle(SoftButton())
                        }.card()
                    } else {
                        switch page {
                        case .now: NowView(addTask: { showNew = true }, editTask: { editing = $0 })
                        case .tasks: TasksView(editTask: { editing = $0 }, addTask: { showNew = true })
                        case .week: WeekView()
                        case .history: HistoryView()
                        }
                    }
                }.padding(34).frame(maxWidth: 1060).frame(maxWidth: .infinity)
            }.background(Theme.canvas)
        }
        .foregroundStyle(Theme.ink).tint(Theme.purple)
        .sheet(isPresented: $showNew) { TaskEditor(task: WorkTask(title: "")) }
        .sheet(item: $editing) { TaskEditor(task: $0) }
        .alert("Something needs attention", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: .newTask)) { _ in showNew = true }
        .onReceive(checkpoint) { _ in store.checkpoint() }
        .onChange(of: phase) { _, newPhase in if newPhase != .active { store.checkpoint() } }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in store.pause() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in store.pause() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "arrow.up.right").font(.system(size: 20, weight: .bold))
                    .frame(width: 36, height: 36).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                Text("next up").font(.system(size: 24, weight: .semibold, design: .rounded))
            }.padding(.bottom, 9)
            Text("A little direction. Real progress.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 44)
            ForEach(Page.allCases, id: \.self) { item in
                Button { page = item } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.symbol).frame(width: 20)
                        Text(item.rawValue).font(.system(size: 14, weight: page == item ? .semibold : .regular))
                        Spacer()
                        if item == .tasks {
                            Text("\(store.data.tasks.filter { !$0.isComplete }.count)")
                                .font(.system(size: 10, weight: .semibold)).padding(5)
                                .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 5))
                        }
                    }.padding(.horizontal, 12).padding(.vertical, 13)
                        .background(page == item ? .white.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white.opacity(page == item ? 1 : 0.62))
                }.buttonStyle(.plain).padding(.bottom, 5)
            }
            Spacer(minLength: 40)
            if store.data.active != nil {
                Button { page = .now } label: { Label("Session in progress", systemImage: "circle.inset.filled") }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Color(red: 0.71, green: 0.83, blue: 0.66))
                    .padding(.bottom, 20)
            }
            VStack(alignment: .leading, spacing: 9) {
                Text("Enough is a good goal.").font(.system(size: 13, weight: .medium))
                Text("Make time for what matters.\nLeave room to be human.")
                    .font(.system(size: 11)).lineSpacing(4).foregroundStyle(.white.opacity(0.47))
            }.padding(.bottom, 24)
            Divider().overlay(.white.opacity(0.1)).padding(.bottom, 16)
            Menu {
                Button("Export backup…") { store.exportBackup() }.disabled(store.loadFailed)
                Button("Show data folder") { store.showDataFolder() }
            } label: { Label("Saved on this Mac", systemImage: "internaldrive") }
                .menuStyle(.borderlessButton).font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 22).padding(.top, 56).padding(.bottom, 24)
        .frame(width: 232).frame(maxHeight: .infinity)
        .background(Color(red: 0.13, green: 0.17, blue: 0.18))
        .foregroundStyle(.white)
    }
}
