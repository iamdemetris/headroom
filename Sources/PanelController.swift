import AppKit

final class PanelController: NSViewController {
    private let fleet: FleetModel
    private let root = NSStackView()
    private let nameField = NSTextField()
    private let hostField = NSTextField()
    private let portField = NSTextField()
    private let formStatus = NSTextField(labelWithString: "")
    private var testTask: Task<Void, Never>?

    init(fleet: FleetModel) {
        self.fleet = fleet
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 520))
        view.wantsLayer = true
        view.layer?.backgroundColor = Palette.ink.cgColor
        self.view = view

        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            root.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16),
            root.widthAnchor.constraint(equalToConstant: 348),
        ])
        configureFields()
        reload()
    }

    func reload() {
        if isEditing { return }
        root.subviews.forEach { $0.removeFromSuperview() }
        if fleet.hosts.isEmpty {
            root.addArrangedSubview(brand())
            root.addArrangedSubview(addForm(showCancel: false))
        } else {
            root.addArrangedSubview(fleetHeader())
            if fleet.showAddHost {
                root.addArrangedSubview(card(addForm(showCancel: true)))
            }
            for host in fleet.hosts {
                root.addArrangedSubview(hostRow(host))
            }
            if let selected = fleet.selected {
                root.addArrangedSubview(detail(selected))
            }
            root.addArrangedSubview(footer())
        }
        preferredContentSize = NSSize(width: 380, height: max(280, root.fittingSize.height + 32))
    }

    private var isEditing: Bool {
        [nameField, hostField, portField].contains { $0.currentEditor() != nil }
    }

    private func configureFields() {
        for field in [nameField, hostField, portField] {
            field.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            field.textColor = Palette.text
            field.backgroundColor = Palette.inkLift
            field.isBezeled = false
            field.focusRingType = .none
            field.drawsBackground = true
            field.wantsLayer = true
            field.layer?.cornerRadius = 8
        }
        nameField.placeholderString = "Production"
        hostField.placeholderString = "prod or user@203.0.113.10"
        portField.placeholderString = "22 if empty"
        formStatus.font = NSFont.systemFont(ofSize: 12)
        formStatus.textColor = Palette.mute
        formStatus.lineBreakMode = .byWordWrapping
        formStatus.maximumNumberOfLines = 4
        formStatus.preferredMaxLayoutWidth = 320
    }

    private func brand() -> NSView {
        let title = text("Headroom", size: 22, weight: .semibold, color: Palette.text)
        let subtitle = text("Those machines, at a glance.", size: 12, weight: .regular, color: Palette.mute)
        let stack = NSStackView(views: [title, subtitle])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        return stack
    }

    private func fleetHeader() -> NSView {
        let title = text("Headroom", size: 13, weight: .semibold, color: Palette.mute)
        let add = NSButton(title: "Add", target: self, action: #selector(toggleAdd))
        add.bezelStyle = .inline
        add.isBordered = false
        add.contentTintColor = Palette.good
        add.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let row = NSStackView(views: [title, NSView(), add])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return row
    }

    private func addForm(showCancel: Bool) -> NSView {
        let heading = text("Add a machine", size: 16, weight: .semibold, color: Palette.text)
        let hint = text("SSH only. Headroom does not install anything on the server.", size: 12, weight: .regular, color: Palette.mute)
        hint.preferredMaxLayoutWidth = 320

        let test = NSButton(title: "Test connection", target: self, action: #selector(testHost))
        let add = NSButton(title: "Add and watch", target: self, action: #selector(addHost))
        style(test)
        style(add)
        add.keyEquivalent = "\r"

        let buttons = NSStackView(views: [test, add])
        buttons.spacing = 8
        if showCancel {
            let cancel = NSButton(title: "Cancel", target: self, action: #selector(toggleAdd))
            style(cancel)
            buttons.addArrangedSubview(cancel)
        }

        let chips = NSStackView()
        chips.orientation = .horizontal
        chips.spacing = 6
        for host in SSHConfigFile.hosts().prefix(8) {
            let chip = NSButton(title: host, target: self, action: #selector(pickSuggestion(_:)))
            chip.bezelStyle = .inline
            chip.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
            chip.contentTintColor = Palette.text
            chips.addArrangedSubview(chip)
        }

        let stack = NSStackView(views: [
            heading, hint,
            labeled("Name", nameField),
            labeled("SSH host", hostField),
            labeled("Port", portField),
        ])
        if !chips.arrangedSubviews.isEmpty {
            stack.addArrangedSubview(text("From your SSH config", size: 11, weight: .medium, color: Palette.mute))
            stack.addArrangedSubview(chips)
        }
        stack.addArrangedSubview(formStatus)
        stack.addArrangedSubview(buttons)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        nameField.translatesAutoresizingMaskIntoConstraints = false
        hostField.translatesAutoresizingMaskIntoConstraints = false
        portField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nameField.widthAnchor.constraint(equalToConstant: 320),
            hostField.widthAnchor.constraint(equalToConstant: 320),
            portField.widthAnchor.constraint(equalToConstant: 320),
            nameField.heightAnchor.constraint(equalToConstant: 28),
            hostField.heightAnchor.constraint(equalToConstant: 28),
            portField.heightAnchor.constraint(equalToConstant: 28),
        ])
        return stack
    }

    private func hostRow(_ host: HostRuntime) -> NSView {
        let selected = host.id == fleet.selectedID
        let button = NSButton(title: "", target: self, action: #selector(selectHost(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(host.id.uuidString)
        button.bezelStyle = .inline
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = Palette.inkLift.withAlphaComponent(selected ? 1 : 0.45).cgColor
        button.layer?.cornerRadius = 10
        button.layer?.borderWidth = 1
        button.layer?.borderColor = (selected ? Palette.good.withAlphaComponent(0.35) : NSColor.white.withAlphaComponent(0.08)).cgColor

        let name = host.config.name
        let subtitle: String
        if let snap = host.snapshot {
            subtitle = String(format: "load %.2f · %d%% mem · %@", snap.load1, Int((snap.memRatio * 100).rounded()), snap.pressure.title)
        } else {
            subtitle = host.lastError ?? "Connecting over SSH…"
        }
        button.attributedTitle = rowTitle(name, subtitle)
        button.alignment = .left
        button.heightAnchor.constraint(equalToConstant: 52).isActive = true
        button.widthAnchor.constraint(equalToConstant: 348).isActive = true
        return button
    }

    private func detail(_ host: HostRuntime) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        if let snap = host.snapshot {
            stack.addArrangedSubview(metric(
                "Load",
                String(format: "%.2f   %.2f   %.2f", snap.load1, snap.load5, snap.load15),
                String(format: "%.0f%% of %d cores", min(snap.loadRatio, 1) * 100, snap.cpus),
                min(snap.loadRatio, 1.15) / 1.15
            ))
            stack.addArrangedSubview(metric(
                "Memory",
                "\(Formatters.mem(snap.memUsedMb)) / \(Formatters.mem(snap.memTotalMb))",
                "\(Formatters.mem(snap.memAvailableMb)) available",
                snap.memRatio
            ))
            stack.addArrangedSubview(metric(
                "Disk",
                String(format: "%.0f / %.0f GB", snap.diskUsedGb, snap.diskTotalGb),
                "\(snap.diskUsedPct)% · up \(Formatters.uptime(snap.uptimeSec))",
                Double(snap.diskUsedPct) / 100
            ))
        } else if let error = host.lastError {
            let err = text(error, size: 12, weight: .regular, color: Palette.hot)
            err.preferredMaxLayoutWidth = 320
            stack.addArrangedSubview(err)
        }

        let refresh = NSButton(title: host.isRefreshing ? "Reading…" : "Refresh", target: self, action: #selector(refreshSelected))
        let ssh = NSButton(title: "Open SSH", target: self, action: #selector(openSSH))
        let remove = NSButton(title: "Remove", target: self, action: #selector(removeSelected))
        [refresh, ssh, remove].forEach(style)
        refresh.isEnabled = !host.isRefreshing
        let actions = NSStackView(views: [refresh, ssh, remove])
        actions.spacing = 8
        stack.addArrangedSubview(actions)
        if let when = host.lastSuccess {
            stack.addArrangedSubview(text(Formatters.relative(when) + " · " + host.config.sshHost, size: 11, weight: .regular, color: Palette.mute))
        }
        return card(stack)
    }

    private func footer() -> NSView {
        let toggle = NSButton(checkboxWithTitle: "Alert when hot", target: self, action: #selector(toggleAlerts))
        toggle.state = fleet.alertsEnabled ? .on : .off
        toggle.font = NSFont.systemFont(ofSize: 11)
        toggle.contentTintColor = Palette.mute
        let quit = NSButton(title: "Quit", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        quit.bezelStyle = .inline
        quit.isBordered = false
        quit.font = NSFont.systemFont(ofSize: 11)
        quit.contentTintColor = Palette.mute
        let row = NSStackView(views: [toggle, NSView(), quit])
        row.orientation = .horizontal
        return row
    }

    private func metric(_ title: String, _ value: String, _ detail: String, _ ratio: Double) -> NSView {
        let head = NSStackView(views: [
            text(title, size: 11, weight: .medium, color: Palette.mute),
            NSView(),
            text(value, size: 11, weight: .medium, color: Palette.text, mono: true),
        ])
        head.orientation = .horizontal
        let track = NSView()
        track.wantsLayer = true
        track.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        track.layer?.cornerRadius = 2.5
        track.heightAnchor.constraint(equalToConstant: 5).isActive = true
        track.widthAnchor.constraint(equalToConstant: 320).isActive = true
        let fill = NSView()
        fill.wantsLayer = true
        fill.layer?.backgroundColor = Palette.bar(ratio).cgColor
        fill.layer?.cornerRadius = 2.5
        fill.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(fill)
        NSLayoutConstraint.activate([
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: max(0.02, min(ratio, 1))),
        ])
        let stack = NSStackView(views: [head, track, text(detail, size: 11, weight: .regular, color: Palette.mute)])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        head.widthAnchor.constraint(equalToConstant: 320).isActive = true
        return stack
    }

    private func labeled(_ title: String, _ field: NSTextField) -> NSView {
        let stack = NSStackView(views: [text(title, size: 11, weight: .medium, color: Palette.mute), field])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        return stack
    }

    private func card(_ inner: NSView) -> NSView {
        let box = NSView()
        box.wantsLayer = true
        box.layer?.backgroundColor = Palette.inkLift.cgColor
        box.layer?.cornerRadius = 12
        inner.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
            inner.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            inner.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            inner.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -12),
            box.widthAnchor.constraint(equalToConstant: 348),
        ])
        return box
    }

    private func text(_ string: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, mono: Bool = false) -> NSTextField {
        let field = NSTextField(labelWithString: string)
        field.font = mono
            ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
            : NSFont.systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.lineBreakMode = .byTruncatingTail
        return field
    }

    private func style(_ button: NSButton) {
        button.bezelStyle = .flexiblePush
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: 12)
    }

    private func rowTitle(_ name: String, _ subtitle: String) -> NSAttributedString {
        let out = NSMutableAttributedString()
        out.append(NSAttributedString(string: name + "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: Palette.text,
        ]))
        out.append(NSAttributedString(string: subtitle, attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: Palette.mute,
        ]))
        return out
    }

    private func draft() -> HostConfig? {
        guard let host = SSHTarget.validateHost(hostField.stringValue) else { return nil }
        let label = SSHTarget.validateName(nameField.stringValue) ?? host
        return HostConfig(name: label, sshHost: host, port: SSHTarget.validatePort(portField.stringValue))
    }

    @objc private func toggleAdd() {
        fleet.toggleAddHost()
    }

    @objc private func pickSuggestion(_ sender: NSButton) {
        hostField.stringValue = sender.title
        if nameField.stringValue.isEmpty {
            nameField.stringValue = sender.title
        }
    }

    @objc private func testHost() {
        guard let config = draft() else {
            formStatus.stringValue = PulseError.invalidHost.localizedDescription
            formStatus.textColor = Palette.hot
            return
        }
        formStatus.stringValue = "Checking…"
        formStatus.textColor = Palette.mute
        testTask?.cancel()
        testTask = Task { [weak self] in
            do {
                let snap = try await SSHCollector.fetch(host: config)
                self?.formStatus.stringValue = "Connected · \(snap.host) · \(snap.cpus) cores · \(Formatters.mem(snap.memTotalMb))"
                self?.formStatus.textColor = Palette.good
            } catch {
                self?.formStatus.stringValue = error.localizedDescription
                self?.formStatus.textColor = Palette.hot
            }
        }
    }

    @objc private func addHost() {
        guard let config = draft() else {
            formStatus.stringValue = PulseError.invalidHost.localizedDescription
            formStatus.textColor = Palette.hot
            return
        }
        nameField.stringValue = ""
        hostField.stringValue = ""
        portField.stringValue = ""
        formStatus.stringValue = ""
        fleet.add(config)
    }

    @objc private func selectHost(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        fleet.select(id)
    }

    @objc private func refreshSelected() {
        guard let host = fleet.selected else { return }
        Task { await fleet.refresh(host) }
    }

    @objc private func openSSH() {
        guard let host = fleet.selected else { return }
        SSHCollector.openTerminal(host: host.config)
    }

    @objc private func removeSelected() {
        guard let host = fleet.selected else { return }
        fleet.remove(host.id)
    }

    @objc private func toggleAlerts(_ sender: NSButton) {
        fleet.alertsEnabled = sender.state == .on
    }
}
