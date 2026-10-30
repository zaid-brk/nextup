import SwiftUI
import NextUpCore

enum Theme {
    static let ink = Color(red: 0.13, green: 0.16, blue: 0.20)
    static let muted = Color(red: 0.42, green: 0.44, blue: 0.47)
    static let canvas = Color(red: 0.97, green: 0.96, blue: 0.94)
    static let purple = Color(red: 0.40, green: 0.33, blue: 0.76)
    static let line = Color.black.opacity(0.07)
    static func tint(_ area: Area) -> Color {
        switch area {
        case .study: purple
        case .project: Color(red: 0.16, green: 0.48, blue: 0.39)
        case .career: Color(red: 0.67, green: 0.39, blue: 0.16)
        case .personal: Color(red: 0.32, green: 0.48, blue: 0.64)
        }
    }
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 20).padding(.vertical, 13)
            .foregroundStyle(.white)
            .background(Theme.purple.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 11))
    }
}

struct SoftButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .foregroundStyle(Theme.ink)
            .background(Theme.ink.opacity(configuration.isPressed ? 0.10 : 0.05), in: RoundedRectangle(cornerRadius: 9))
    }
}

extension View {
    func card() -> some View {
        self.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1))
    }
    func eyebrow() -> some View {
        self.font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(Theme.muted)
    }
}

struct AreaBadge: View {
    let area: Area
    var body: some View {
        Text(area.rawValue)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.tint(area))
    }
}

func durationLabel(_ minutes: Int) -> String {
    if minutes < 60 { return "\(minutes) min" }
    let hours = minutes / 60, rest = minutes % 60
    return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
}
