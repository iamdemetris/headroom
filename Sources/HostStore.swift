import Foundation

enum HostStore {
    static var fileURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = root.appendingPathComponent("Headroom", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("hosts.json")
    }

    static func load() -> [HostConfig] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([HostConfig].self, from: data)) ?? []
    }

    static func save(_ hosts: [HostConfig]) {
        let data = try? JSONEncoder().encode(hosts)
        if let data {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

enum SSHConfigFile {
    static func hosts(from text: String? = nil) -> [String] {
        let contents: String
        if let text {
            contents = text
        } else {
            let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh/config")
            contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        var names: [String] = []
        let skip: Set<String> = ["*", "github.com", "gitlab.com", "bitbucket.org"]
        for line in contents.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.lowercased().hasPrefix("host ") else { continue }
            let rest = trimmed.dropFirst(5)
            for token in rest.split(whereSeparator: \.isWhitespace) {
                let name = String(token)
                if skip.contains(name) || name.contains("*") || name.contains("?") { continue }
                if SSHTarget.validateHost(name) != nil, !names.contains(name) {
                    names.append(name)
                }
            }
        }
        return names
    }
}
