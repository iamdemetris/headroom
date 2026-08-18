import AppKit
import SwiftUI

enum Hue {
    static let bg = Color(red: 0.043, green: 0.067, blue: 0.102)
    static let card = Color(red: 0.090, green: 0.122, blue: 0.176)
    static let stroke = Color.white.opacity(0.08)
    static let text = Color(red: 0.973, green: 0.980, blue: 0.988)
    static let mute = Color.white.opacity(0.55)
    static let good = Color(red: 0.133, green: 0.773, blue: 0.369)
    static let busy = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let hot = Color(red: 0.941, green: 0.267, blue: 0.267)

    static func pressure(_ value: Pressure?) -> Color {
        switch value {
        case .ok: good
        case .warn: busy
        case .hot: hot
        case .none: mute
        }
    }
}

struct RootView: View {
    @Bindable var fleet: FleetModel

    var body: some View {
        ZStack {
            Hue.bg.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.16, blue: 0.12).opacity(0.55), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()

            if fleet.hosts.isEmpty || fleet.showAddHost {
                AddMachineView(fleet: fleet)
            } else {
                FleetScreen(fleet: fleet)
            }
        }
        .frame(minWidth: 440, minHeight: 580)
        .preferredColorScheme(.dark)
    }
}

struct AddMachineView: View {
    @Bindable var fleet: FleetModel
    @State private var name = ""
    @State private var sshHost = ""
    @State private var port = ""
    @State private var testing = false
    @State private var status = ""
    @State private var statusGood = false
    @State private var suggestions: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                card
            }
            .padding(28)
        }
        .onAppear { suggestions = SSHConfigFile.hosts() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            GaugeMark()
            Text("Headroom")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(Hue.text)
            Text("Those machines, at a glance.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Hue.mute)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add a machine")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Hue.text)
                Text("Uses SSH you already have. Nothing is installed on the server.")
                    .font(.system(size: 13))
                    .foregroundStyle(Hue.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }

            field("Name", text: $name, hint: "Production")
            field("SSH host", text: $sshHost, hint: "alias or user@host")
            field("Port", text: $port, hint: "Optional")

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("On this Mac")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Hue.mute)
                    FlowChips(items: suggestions, selected: sshHost) { host in
                        sshHost = host
                        if name.isEmpty { name = host }
                    }
                }
            }

            if !status.isEmpty {
                Text(status)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(statusGood ? Hue.good : Hue.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                GhostButton(title: testing ? "Checking…" : "Test connection", enabled: !testing && valid) {
                    Task { await test() }
                }
                PrimaryButton(title: "Add and watch", enabled: valid) {
                    save()
                }
            }

            if fleet.showAddHost, !fleet.hosts.isEmpty {
                Button("Cancel") { fleet.toggleAddHost() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Hue.mute)
            }
        }
        .padding(22)
        .background(Hue.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Hue.stroke, lineWidth: 1)
        )
    }

    private var valid: Bool { SSHTarget.validateHost(sshHost) != nil }

    private func field(_ title: String, text: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Hue.mute)
            TextField(hint, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(Hue.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Hue.stroke, lineWidth: 1)
                )
        }
    }

    private func draft() -> HostConfig? {
        guard let host = SSHTarget.validateHost(sshHost) else { return nil }
        return HostConfig(name: SSHTarget.validateName(name) ?? host, sshHost: host, port: SSHTarget.validatePort(port))
    }

    private func test() async {
        guard let config = draft() else {
            status = PulseError.invalidHost.localizedDescription
            statusGood = false
            return
        }
        testing = true
        defer { testing = false }
        do {
            let snap = try await SSHCollector.fetch(host: config)
            status = "Connected · \(snap.cpus) cores · \(Formatters.mem(snap.memTotalMb))"
            statusGood = true
        } catch {
            status = error.localizedDescription
            statusGood = false
        }
    }

    private func save() {
        guard let config = draft() else { return }
        fleet.add(config)
        name = ""; sshHost = ""; port = ""; status = ""
    }
}

struct FleetScreen: View {
    @Bindable var fleet: FleetModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    GaugeMark(size: 28)
                    Text("Headroom")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Hue.text)
                    Spacer()
                    Button {
                        fleet.toggleAddHost()
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Hue.good)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(fleet.hosts) { host in
                    HostCard(host: host, selected: host.id == fleet.selectedID) {
                        fleet.select(host.id)
                    }
                }

                if let selected = fleet.selected {
                    DetailCard(host: selected, fleet: fleet)
                }

                HStack {
                    Toggle("Alert when hot", isOn: $fleet.alertsEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .font(.system(size: 12))
                        .foregroundStyle(Hue.mute)
                    Spacer()
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Hue.mute)
                }
                .padding(.top, 4)
            }
            .padding(24)
        }
    }
}

struct HostCard: View {
    var host: HostRuntime
    var selected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Circle()
                    .fill(Hue.pressure(host.pressure))
                    .frame(width: 10, height: 10)
                    .shadow(color: Hue.pressure(host.pressure).opacity(0.7), radius: 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(host.config.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Hue.text)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Hue.mute)
                }
                Spacer()
                if let snap = host.snapshot {
                    Text("\(Int((snap.memRatio * 100).rounded()))%")
                        .font(.system(size: 15, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(Hue.text)
                }
            }
            .padding(16)
            .background(Hue.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Hue.good.opacity(0.45) : Hue.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        if let snap = host.snapshot {
            return String(format: "load %.2f · %d cores · %@", snap.load1, snap.cpus, snap.pressure.title)
        }
        return host.lastError ?? "Connecting…"
    }
}

struct DetailCard: View {
    var host: HostRuntime
    var fleet: FleetModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let snap = host.snapshot {
                meter("Load", String(format: "%.2f    %.2f    %.2f", snap.load1, snap.load5, snap.load15),
                      String(format: "%.0f%% of %d cores", min(snap.loadRatio, 1) * 100, snap.cpus),
                      min(snap.loadRatio, 1.15) / 1.15)
                meter("Memory", "\(Formatters.mem(snap.memUsedMb))  /  \(Formatters.mem(snap.memTotalMb))",
                      "\(Formatters.mem(snap.memAvailableMb)) free", snap.memRatio)
                meter("Disk", String(format: "%.0f / %.0f GB", snap.diskUsedGb, snap.diskTotalGb),
                      "\(snap.diskUsedPct)% · up \(Formatters.uptime(snap.uptimeSec))",
                      Double(snap.diskUsedPct) / 100)
            } else if let error = host.lastError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Hue.hot)
            }

            HStack(spacing: 10) {
                GhostButton(title: host.isRefreshing ? "Reading…" : "Refresh", enabled: !host.isRefreshing) {
                    Task { await fleet.refresh(host) }
                }
                GhostButton(title: "Open SSH", enabled: true) {
                    SSHCollector.openTerminal(host: host.config)
                }
                Spacer()
                Button("Remove") { fleet.remove(host.id) }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Hue.hot)
            }

            if let when = host.lastSuccess {
                Text(Formatters.relative(when) + "  ·  " + host.config.sshHost)
                    .font(.system(size: 12))
                    .foregroundStyle(Hue.mute)
            }
        }
        .padding(18)
        .background(Hue.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Hue.stroke, lineWidth: 1)
        )
    }

    private func meter(_ title: String, _ value: String, _ detail: String, _ ratio: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Hue.mute)
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Hue.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Hue.pressure(ratio >= 0.85 ? .hot : ratio >= 0.70 ? .warn : .ok))
                        .frame(width: max(8, geo.size.width * min(max(ratio, 0), 1)))
                }
            }
            .frame(height: 6)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(Hue.mute)
        }
    }
}

struct FlowChips: View {
    let items: [String]
    var selected: String
    var onPick: (String) -> Void

    var body: some View {
        FlexibleHStack(items: items) { item in
            Button {
                onPick(item)
            } label: {
                Text(item)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(item == selected ? Hue.bg : Hue.text)
                    .background(item == selected ? Hue.good : Color.white.opacity(0.06), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

struct FlexibleHStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        // Keep it simple and reliable: wrap into a leading-aligned wrap via LazyVGrid.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}

struct GaugeMark: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .stroke(Hue.good.opacity(0.22), lineWidth: 3.5)
            Circle()
                .trim(from: 0.12, to: 0.68)
                .stroke(Hue.good, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-80))
            Circle()
                .fill(Hue.good)
                .frame(width: size * 0.2, height: size * 0.2)
                .shadow(color: Hue.good.opacity(0.8), radius: 6)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct PrimaryButton: View {
    let title: String
    var enabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(enabled ? Hue.bg : Hue.mute)
                .background(enabled ? Hue.good : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct GhostButton: View {
    let title: String
    var enabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .foregroundStyle(enabled ? Hue.text : Hue.mute)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Hue.stroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
