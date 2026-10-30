import Foundation

public struct Recommendation: Identifiable, Sendable {
    public var id: UUID { task.id }
    public var task: WorkTask
    public var minutes: Int
    public var reasons: [String]
    public var score: Double
}

public enum Planner {
    // A fixed Monday boundary avoids recommendations changing with a system locale's first weekday.
    public static func weekStart(at now: Date, calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = 2; cal.minimumDaysInFirstWeek = 4
        return cal.dateInterval(of: .weekOfYear, for: now)!.start
    }

    public static func secondsThisWeek(_ data: AppData, area: Area? = nil,
                                       now: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = weekStart(at: now, calendar: calendar)
        return data.sessions.filter { $0.endedAt >= start && $0.endedAt <= now && (area == nil || $0.area == area) }
            .reduce(0) { $0 + $1.seconds }
    }

    public static func ranked(_ data: AppData, available: Int, energy: Energy,
                              excluding: Set<UUID> = [], now: Date = Date(),
                              calendar: Calendar = .current) -> [Recommendation] {
        guard available > 0 else { return [] }
        return data.tasks.filter {
            !$0.isComplete && !$0.isBlocked && !excluding.contains($0.id) && $0.energy.rawValue <= energy.rawValue
        }.map { task in
            var reasons: [String] = []
            var score = Double(task.priority * 12)
            if let due = task.due {
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                                    to: calendar.startOfDay(for: due)).day ?? 0
                if days < 0 { score += 220; reasons.append("Overdue — this needs attention first.") }
                else if days == 0 { score += 190; reasons.append("Due today.") }
                else if days == 1 { score += 150; reasons.append("Due tomorrow.") }
                else if days <= 3 { score += 105; reasons.append("Due in \(days) days.") }
                else if days <= 7 { score += 45; reasons.append("Due this coming week.") }
                // A large assignment gets attention before its deadline becomes an emergency.
                if days > 0 && days <= 14 {
                    let dailyLoad = Double(task.remainingMinutes) / Double(days)
                    score += min(60, dailyLoad / 2)
                    if dailyLoad >= 60 { reasons.append("A larger task — an early start will help.") }
                }
            }
            let target = data.targets.first { $0.area == task.area }?.minutes ?? 0
            let done = Double(secondsThisWeek(data, area: task.area, now: now, calendar: calendar)) / 60
            if target > 0 && done < Double(target) {
                score += 50 * (1 - done / Double(target))
                reasons.append("\(task.area.rawValue) has \(max(1, Int(ceil(Double(target) - done)))) min left in your weekly target.")
            }
            if task.remainingMinutes <= available {
                score += 12; reasons.append("Fits your \(available)-minute window.")
            } else {
                reasons.append("Use \(available) minutes to move this forward; the full task needs about \(task.remainingMinutes) min.")
            }
            if task.priority == 3 { reasons.append("You marked this as high priority.") }
            if task.energy == energy { score += 5 }
            return Recommendation(task: task, minutes: min(available, task.remainingMinutes), reasons: reasons, score: score)
        }.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.task.createdAt != $1.task.createdAt { return $0.task.createdAt < $1.task.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
