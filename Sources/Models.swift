import Foundation

struct HostConfig: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var sshHost: String
    var port: Int?

    init(id: UUID = UUID(), name: String, sshHost: String, port: Int? = nil) {
        self.id = id
        self.name = name
        self.sshHost = sshHost
        self.port = port
    }
}

enum SSHTarget {
    static func validateHost(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("-"), value.count <= 253 else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_@"))
        guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        if value.contains("@") {
            let parts = value.split(separator: "@", omittingEmptySubsequences: false)
            guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        }
        return value
    }

    static func validatePort(_ raw: String) -> Int? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }
        guard let port = Int(value), (1...65_535).contains(port) else { return nil }
        return port
    }

    static func validateName(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...40).contains(value.count) else { return nil }
        return value
    }
}

struct HostSnapshot: Decodable, Sendable {
    let host: String
    let cpus: Int
    let load1: Double
    let load5: Double
    let load15: Double
    let memTotalMb: Int
    let memUsedMb: Int
    let memAvailableMb: Int
    let swapTotalMb: Int
    let swapUsedMb: Int
    let diskTotalGb: Double
    let diskUsedGb: Double
    let diskUsedPct: Int
    let uptimeSec: Int

    enum CodingKeys: String, CodingKey {
        case host, cpus, load1, load5, load15
        case memTotalMb = "mem_total_mb"
        case memUsedMb = "mem_used_mb"
        case memAvailableMb = "mem_available_mb"
        case swapTotalMb = "swap_total_mb"
        case swapUsedMb = "swap_used_mb"
        case diskTotalGb = "disk_total_gb"
        case diskUsedGb = "disk_used_gb"
        case diskUsedPct = "disk_used_pct"
        case uptimeSec = "uptime_sec"
    }

    var memRatio: Double {
        guard memTotalMb > 0 else { return 0 }
        return Double(memUsedMb) / Double(memTotalMb)
    }

    var loadRatio: Double {
        guard cpus > 0 else { return load1 }
        return load1 / Double(cpus)
    }

    var pressure: Pressure {
        Pressure.combined(load: loadRatio, mem: memRatio, disk: diskUsedPct)
    }
}

enum Pressure: Int, Comparable, Sendable {
    case ok = 0
    case warn = 1
    case hot = 2

    static func < (lhs: Pressure, rhs: Pressure) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .ok: "Headroom"
        case .warn: "Busy"
        case .hot: "Saturated"
        }
    }

    static func combined(load: Double, mem: Double, disk: Int) -> Pressure {
        max(
            band(load, warn: 0.60, hot: 1.00),
            band(mem, warn: 0.70, hot: 0.85),
            band(Double(disk) / 100, warn: 0.80, hot: 0.90)
        )
    }

    private static func band(_ value: Double, warn: Double, hot: Double) -> Pressure {
        if value >= hot { return .hot }
        if value >= warn { return .warn }
        return .ok
    }
}

enum PulseError: LocalizedError, Sendable {
    case invalidHost
    case ssh(String)
    case decode
    case timeout
    case tooLarge
    case missingCollector

    var errorDescription: String? {
        switch self {
        case .invalidHost:
            return "That SSH host does not look safe. Use an alias like prod or user@192.0.2.10."
        case .ssh(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "SSH could not reach that machine." : trimmed
        case .decode:
            return "The machine answered, but the snapshot was not valid JSON."
        case .timeout:
            return "The machine did not answer in time."
        case .tooLarge:
            return "The snapshot was larger than Headroom will accept."
        case .missingCollector:
            return "The Headroom collector is missing from the app bundle."
        }
    }
}

@MainActor
final class HostRuntime: Identifiable {
    nonisolated let id: UUID
    var config: HostConfig
    var snapshot: HostSnapshot?
    var lastSuccess: Date?
    var lastError: String?
    var isRefreshing = false

    var pressure: Pressure? { snapshot?.pressure }

    init(config: HostConfig) {
        self.id = config.id
        self.config = config
    }
}
