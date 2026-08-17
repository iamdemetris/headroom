import SwiftUI

struct AddHostView: View {
    @Bindable var fleet: FleetModel
    var onCancel: (() -> Void)?

    @State private var name = ""
    @State private var sshHost = ""
    @State private var port = ""
    @State private var testing = false
    @State private var testError: String?
    @State private var preview: HostSnapshot?
    @State private var suggestions: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add a machine")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text("SSH only. Headroom does not install anything on the server.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }

            field("Name", text: $name, placeholder: "Production")
            field("SSH host", text: $sshHost, placeholder: "prod or user@203.0.113.10")
            field("Port", text: $port, placeholder: "22 if empty")

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("From your SSH config")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.mute)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(suggestions, id: \.self) { host in
                                Button(host) {
                                    sshHost = host
                                    if name.isEmpty { name = host }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Theme.inkLift, in: Capsule())
                                .foregroundStyle(Theme.text)
                            }
                        }
                    }
                }
            }

            if let preview {
                PreviewCard(snapshot: preview)
            } else if let testError {
                Text(testError)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button(testing ? "Checking…" : "Test connection") {
                    Task { await test() }
                }
                .disabled(testing || SSHTarget.validateHost(sshHost) == nil)
                Button("Add and watch") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.good)
                .disabled(preview == nil)
                Spacer()
                if let onCancel {
                    Button("Cancel", action: onCancel)
                }
            }
            .controlSize(.small)
        }
        .onAppear {
            suggestions = SSHConfigFile.hosts()
        }
    }

    private func field(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.mute)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Theme.inkLift, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(Theme.text)
                .font(.system(size: 13, design: .monospaced))
        }
    }

    private func draftConfig() -> HostConfig? {
        guard let host = SSHTarget.validateHost(sshHost) else { return nil }
        let label = SSHTarget.validateName(name) ?? host
        return HostConfig(name: label, sshHost: host, port: SSHTarget.validatePort(port))
    }

    private func test() async {
        guard let config = draftConfig() else {
            testError = PulseError.invalidHost.localizedDescription
            preview = nil
            return
        }
        testing = true
        testError = nil
        preview = nil
        defer { testing = false }
        do {
            preview = try await SSHCollector.fetch(host: config)
        } catch {
            testError = error.localizedDescription
        }
    }

    private func save() {
        guard let config = draftConfig() else { return }
        fleet.add(config)
        name = ""
        sshHost = ""
        port = ""
        preview = nil
        testError = nil
    }
}

struct PreviewCard: View {
    let snapshot: HostSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Connected · \(snapshot.host)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.good)
            Text("\(snapshot.cpus) cores · \(Formatters.mem(snapshot.memTotalMb)) · load \(String(format: "%.2f", snapshot.load1))")
                .font(.system(size: 12))
                .foregroundStyle(Theme.mute)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.good.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
