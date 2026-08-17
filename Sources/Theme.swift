import SwiftUI

enum Theme {
    static let ink = Color(red: 0.06, green: 0.09, blue: 0.16)
    static let inkLift = Color(red: 0.12, green: 0.16, blue: 0.24)
    static let line = Color.white.opacity(0.08)
    static let text = Color(red: 0.97, green: 0.98, blue: 0.99)
    static let mute = Color.white.opacity(0.58)
    static let good = Color(red: 0.13, green: 0.77, blue: 0.37)
    static let busy = Color(red: 0.96, green: 0.62, blue: 0.07)
    static let hot = Color(red: 0.94, green: 0.27, blue: 0.29)
    static let offline = Color.white.opacity(0.35)

    static func pressure(_ value: Pressure?) -> Color {
        switch value {
        case .ok: good
        case .warn: busy
        case .hot: hot
        case .none: offline
        }
    }
}

enum Formatters {
    static func mem(_ mb: Int) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", Double(mb) / 1024.0)
        }
        return "\(mb) MB"
    }

    static func uptime(_ seconds: Int) -> String {
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let mins = (seconds % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }

    static func relative(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 2 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        return "\(seconds / 60)m ago"
    }
}
