import AppKit
import SwiftUI

struct MenuLabel: View {
    var fleet: FleetModel

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.pressure(fleet.worstPressure))
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
        }
        .accessibilityLabel(access)
    }

    private var text: String {
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

    private var access: String {
        if fleet.hosts.isEmpty { return "Headroom, no machines yet" }
        return "Headroom, \(fleet.hosts.count) machines"
    }
}

struct MenuRoot: View {
    @Bindable var fleet: FleetModel

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()
            if fleet.hosts.isEmpty {
                empty
            } else {
                fleetView
            }
        }
        .frame(width: 380)
        .preferredColorScheme(.dark)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 18) {
            brand
            AddHostView(fleet: fleet)
        }
        .padding(18)
    }

    private var brand: some View {
        HStack(spacing: 12) {
            Mark()
            VStack(alignment: .leading, spacing: 2) {
                Text("Headroom")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text("Those machines, at a glance.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mute)
            }
        }
    }

    private var fleetView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Headroom")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.mute)
                Spacer()
                Button {
                    fleet.showAddHost.toggle()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.good)
                .font(.system(size: 12, weight: .semibold))
            }

            if fleet.showAddHost {
                AddHostView(fleet: fleet, onCancel: { fleet.showAddHost = false })
                    .padding(12)
                    .background(Theme.inkLift, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(spacing: 8) {
                ForEach(fleet.hosts) { host in
                    HostRow(host: host, selected: host.id == fleet.selectedID) {
                        fleet.selectedID = host.id
                    }
                }
            }

            if let selected = fleet.selected {
                HostDetail(host: selected, fleet: fleet)
            }

            footer
        }
        .padding(16)
    }

    private var footer: some View {
        HStack {
            Toggle("Alert when hot", isOn: $fleet.alertsEnabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.system(size: 11))
                .foregroundStyle(Theme.mute)
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Theme.mute)
        }
    }
}

struct Mark: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.good.opacity(0.35), lineWidth: 3)
                .frame(width: 36, height: 36)
            Circle()
                .trim(from: 0.12, to: 0.62)
                .stroke(Theme.good, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 36, height: 36)
                .rotationEffect(.degrees(-80))
            Circle()
                .fill(Theme.good)
                .frame(width: 7, height: 7)
        }
        .accessibilityHidden(true)
    }
}

struct HostRow: View {
    var host: HostRuntime
    var selected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Theme.pressure(host.pressure))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(host.config.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.mute)
                }
                Spacer()
                if let snap = host.snapshot {
                    Text("\(Int((snap.memRatio * 100).rounded()))%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.text)
                } else if host.isRefreshing {
                    ProgressView().controlSize(.mini)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Theme.inkLift : Theme.inkLift.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? Theme.good.opacity(0.35) : Theme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        if let snap = host.snapshot {
            return String(format: "load %.2f · CPU %.0f%% · %@", snap.load1, snap.cpuPct, snap.pressure.title)
        }
        return host.lastError ?? "Connecting over SSH…"
    }
}

struct HostDetail: View {
    var host: HostRuntime
    var fleet: FleetModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let snap = host.snapshot {
                metric("Load", value: String(format: "%.2f   %.2f   %.2f", snap.load1, snap.load5, snap.load15),
                       detail: String(format: "%.0f%% of %d cores · live CPU %.0f%%", min(snap.loadRatio, 1) * 100, snap.cpus, snap.cpuPct),
                       ratio: min(snap.loadRatio, 1.15) / 1.15)
                metric("Memory", value: "\(Formatters.mem(snap.memUsedMb)) / \(Formatters.mem(snap.memTotalMb))",
                       detail: "\(Formatters.mem(snap.memAvailableMb)) available",
                       ratio: snap.memRatio)
                metric("Disk", value: String(format: "%.0f / %.0f GB", snap.diskUsedGb, snap.diskTotalGb),
                       detail: "\(snap.diskUsedPct)% · up \(Formatters.uptime(snap.uptimeSec))",
                       ratio: Double(snap.diskUsedPct) / 100)
                if !snap.top.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top CPU")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.mute)
                        ForEach(snap.top) { row in
                            HStack {
                                Text(row.name)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(Theme.text)
                                Spacer()
                                Text(String(format: "%.1f%%", row.cpu))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Theme.mute)
                            }
                        }
                    }
                }
            } else if let error = host.lastError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button(host.isRefreshing ? "Reading…" : "Refresh") {
                    Task { await fleet.refresh(host) }
                }
                .disabled(host.isRefreshing)
                Button("Open SSH") { SSHCollector.openTerminal(host: host.config) }
                Spacer()
                Button("Remove", role: .destructive) { fleet.remove(host.id) }
            }
            .controlSize(.small)
            .font(.system(size: 12))

            if let when = host.lastSuccess {
                Text(Formatters.relative(when) + " · " + host.config.sshHost)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.mute)
            }
        }
        .padding(12)
        .background(Theme.inkLift, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metric(_ title: String, value: String, detail: String, ratio: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.mute)
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(bar(ratio))
                        .frame(width: max(4, geo.size.width * min(max(ratio, 0), 1)))
                }
            }
            .frame(height: 5)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(Theme.mute)
        }
    }

    private func bar(_ ratio: Double) -> Color {
        if ratio >= 0.85 { return Theme.hot }
        if ratio >= 0.70 { return Theme.busy }
        return Theme.good
    }
}
