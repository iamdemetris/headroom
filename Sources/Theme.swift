import AppKit

enum Palette {
    static let ink = NSColor(srgbRed: 0.06, green: 0.09, blue: 0.16, alpha: 1)
    static let inkLift = NSColor(srgbRed: 0.12, green: 0.16, blue: 0.24, alpha: 1)
    static let text = NSColor(srgbRed: 0.97, green: 0.98, blue: 0.99, alpha: 1)
    static let mute = NSColor(srgbRed: 0.97, green: 0.98, blue: 0.99, alpha: 0.58)
    static let good = NSColor(srgbRed: 0.13, green: 0.77, blue: 0.37, alpha: 1)
    static let busy = NSColor(srgbRed: 0.96, green: 0.62, blue: 0.07, alpha: 1)
    static let hot = NSColor(srgbRed: 0.94, green: 0.27, blue: 0.29, alpha: 1)
    static let offline = NSColor(srgbRed: 0.97, green: 0.98, blue: 0.99, alpha: 0.35)

    static func pressure(_ value: Pressure?) -> NSColor {
        switch value {
        case .ok: good
        case .warn: busy
        case .hot: hot
        case .none: offline
        }
    }

    static func bar(_ ratio: Double) -> NSColor {
        if ratio >= 0.85 { return hot }
        if ratio >= 0.70 { return busy }
        return good
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

    @MainActor
    static func statusTitle(_ fleet: FleetModel) -> String {
        if fleet.hosts.isEmpty { return "Headroom" }
        if fleet.hosts.count == 1, let host = fleet.hosts.first {
            let short = String(host.config.name.prefix(12))
            if let snap = host.snapshot {
                return String(format: "%@ %.2f · %d%%", short, snap.load1, Int((snap.memRatio * 100).rounded()))
            }
            return host.lastError == nil ? "\(short) …" : "\(short) ✕"
        }
        let ready = fleet.hosts.filter { $0.snapshot != nil }.count
        if let worst = fleet.hosts.max(by: { ($0.pressure?.rawValue ?? -1) < ($1.pressure?.rawValue ?? -1) }),
           worst.pressure == .hot || worst.pressure == .warn,
           let snap = worst.snapshot {
            return String(format: "%@ %.2f", worst.config.name, snap.load1)
        }
        return "\(ready)/\(fleet.hosts.count) up"
    }
}
