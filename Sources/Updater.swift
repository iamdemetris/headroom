import Foundation

/// A release fetched from the GitHub Releases API (https://api.github.com).
struct UpdateInfo: Codable, Equatable {
    var tagName: String
    var name: String
    var body: String?
    var htmlUrl: String
    var publishedAt: String?
    var assets: [ReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

struct ReleaseAsset: Codable, Equatable {
    var name: String
    var browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
}

/// Latest release published for this repo on GitHub, or nil on failure.
struct GitHubRelease {
    static func latest(repo: String, timeout: TimeInterval = 12) async -> UpdateInfo? {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Headroom/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let info = try JSONDecoder().decode(UpdateInfo.self, from: data)
            return info
        } catch {
            return nil
        }
    }
}

/// Compares two semver-ish strings ("0.9", "0.1.12-beta"). Returns true when lhs is newer.
enum VersionCompare {
    static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        let a = numeric(lhs)
        let b = numeric(rhs)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x > y { return true }
            if x < y { return false }
        }
        return false
    }

    private static func numeric(_ s: String) -> [Int] {
        let clean = s.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split(whereSeparator: { !$0.isNumber && $0 != "." })
            .joined(separator: ".")
        return clean.split(separator: ".").compactMap { Int($0) }
    }
}
