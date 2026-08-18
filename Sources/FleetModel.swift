import Foundation
import Observation
import UserNotifications

@Observable
@MainActor
final class FleetModel {
    static let pollInterval: Duration = .seconds(30)

    var hosts: [HostRuntime] = []
    var selectedID: UUID?
    var showAddHost = false
    var alertsEnabled = UserDefaults.standard.object(forKey: "alertsEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(alertsEnabled, forKey: "alertsEnabled") }
    }
    var onChange: (() -> Void)?

    private var loop: Task<Void, Never>?
    private var lastAlert: [UUID: Date] = [:]

    var selected: HostRuntime? {
        hosts.first(where: { $0.id == selectedID }) ?? hosts.first
    }

    var worstPressure: Pressure? {
        hosts.compactMap(\.pressure).max()
    }

    func start() {
        if hosts.isEmpty {
            hosts = HostStore.load().map(HostRuntime.init)
            selectedID = hosts.first?.id
        }
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refreshAll()
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    func add(_ config: HostConfig) {
        let runtime = HostRuntime(config: config)
        hosts.append(runtime)
        selectedID = runtime.id
        showAddHost = false
        persist()
        notify()
        Task { await refresh(runtime) }
    }

    func remove(_ id: UUID) {
        hosts.removeAll { $0.id == id }
        if selectedID == id {
            selectedID = hosts.first?.id
        }
        persist()
        notify()
    }

    func select(_ id: UUID) {
        selectedID = id
        notify()
    }

    func toggleAddHost() {
        showAddHost.toggle()
        notify()
    }

    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            for host in hosts {
                group.addTask { await self.refresh(host) }
            }
        }
    }

    func refresh(_ host: HostRuntime) async {
        if host.isRefreshing { return }
        host.isRefreshing = true
        notify()
        defer {
            host.isRefreshing = false
            notify()
        }
        do {
            let snap = try await SSHCollector.fetch(host: host.config)
            host.snapshot = snap
            host.lastSuccess = Date()
            host.lastError = nil
            await notifyIfNeeded(host)
        } catch {
            host.lastError = error.localizedDescription
        }
    }

    func notify() {
        onChange?()
    }

    private func persist() {
        HostStore.save(hosts.map(\.config))
    }

    private func notifyIfNeeded(_ host: HostRuntime) async {
        guard alertsEnabled, host.pressure == .hot else { return }
        let last = lastAlert[host.id] ?? .distantPast
        guard Date().timeIntervalSince(last) > 15 * 60 else { return }
        lastAlert[host.id] = Date()
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound])
        guard granted == true else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(host.config.name) is saturated"
        if let snap = host.snapshot {
            content.body = "Load \(String(format: "%.2f", snap.load1)) on \(snap.cpus) cores · memory \(Int(snap.memRatio * 100))%."
        }
        content.sound = .default
        try? await center.add(
            UNNotificationRequest(identifier: "headroom-\(host.id.uuidString)", content: content, trigger: nil)
        )
    }
}
