import Foundation

enum SSHCollector {
    private static let maxBytes = 16 * 1024
    private static let script: Data? = {
        if let url = Bundle.main.url(forResource: "collector", withExtension: "py") {
            return try? Data(contentsOf: url)
        }
        let dev = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/collector.py")
        return try? Data(contentsOf: dev)
    }()

    static func fetch(host: HostConfig, timeout: TimeInterval = 8) async throws -> HostSnapshot {
        guard let target = SSHTarget.validateHost(host.sshHost) else {
            throw PulseError.invalidHost
        }
        guard let script else {
            throw PulseError.missingCollector
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        var args = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=6",
            "-o", "ServerAliveInterval=10",
            "-o", "ServerAliveCountMax=2",
            "-o", "ControlMaster=auto",
            "-o", "ControlPath=~/.ssh/headroom-%C",
            "-o", "ControlPersist=300",
        ]
        if let port = host.port {
            args += ["-p", String(port)]
        }
        args += [target, "python3", "-"]
        process.arguments = args

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        stdin.fileHandleForWriting.write(script)
        try? stdin.fileHandleForWriting.close()

        let timedOut = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                process.waitUntilExit()
                return false
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                return true
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }

        if timedOut && process.isRunning {
            process.terminate()
            process.waitUntilExit()
            throw PulseError.timeout
        }

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let message = String(data: errData, encoding: .utf8) ?? ""
            throw PulseError.ssh(message)
        }
        guard outData.count <= maxBytes else {
            throw PulseError.tooLarge
        }
        do {
            return try JSONDecoder().decode(HostSnapshot.self, from: outData)
        } catch {
            throw PulseError.decode
        }
    }

    static func openTerminal(host: HostConfig) {
        guard let target = SSHTarget.validateHost(host.sshHost) else { return }
        var command = "ssh"
        if let port = host.port {
            command += " -p \(port)"
        }
        command += " \(target)"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            "tell application \"Terminal\" to activate",
            "-e",
            "tell application \"Terminal\" to do script \"\(command)\"",
        ]
        try? process.run()
    }
}
