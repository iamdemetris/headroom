import Foundation
import AppKit
import UserNotifications

/// Coordinates self-updates. Depends only on the GitHub Releases flow the
/// release script already drives, so it stays network-light and honest.
@MainActor
final class UpdateManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let repo = "iamdemetris/headroom"
    private static let repoKey = "lastChecked"

    enum Phase: Equatable {
        case idle
        case checking
        case ready(UpdateInfo)
        case downloading(Double, UpdateInfo)
        case failed(String)
    }

    @Published var phase: Phase = .idle
    var onPhaseChange: (() -> Void)?

    /// Latest release to offer (may be >= current, including current).
    private var latest: UpdateInfo?

    /// Current running app version.
    private var currentVersion: String { AppInfo.version }

    private var downloadTask: URLSessionDownloadTask?
    private var downloadedURL: URL?
    private var expectedInfo: UpdateInfo?

    // MARK: - API

    func start() {
        // Frequent but light: GitHub releases/latest is tiny (~1KB). First
        // check immediately (this powers the "push a release -> get the
        // popup" flow), then re-check at most once per hour.
        Task { await check() }
        scheduleNextCheck()
    }

    private func scheduleNextCheck() {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3600))
            guard let self else { return }
            await self.check()
            self.scheduleNextCheck()
        }
    }

    func check() async {
        // Avoid piling on while a previous check/install is in flight.
        guard case .idle = phase else { return }
        phase = .checking
        let repoURL = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!
        var request = URLRequest(url: repoURL)
        request.timeoutInterval = 12
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                phase = .idle
                return
            }
            let info = try JSONDecoder().decode(UpdateInfo.self, from: data)
            latest = info
            phase = .idle
            let offered = VersionCompare.isNewer(info.tagName, than: currentVersion)
            if offered {
                phase = .ready(info)
                notifyUpdateAvailable(info)
            }
        } catch {
            phase = .idle
        }
    }

    func checkNow() {
        Task { await check() }
    }

    func install(_ info: UpdateInfo) {
        guard let asset = info.assets.first(where: { $0.name.hasSuffix(".dmg") }) ?? info.assets.first else {
            phase = .failed("No download for this release.")
            return
        }
        expectedInfo = info
        phase = .downloading(0, info)
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        guard let url = URL(string: asset.browserDownloadUrl) else {
            phase = .failed("Bad download URL.")
            return
        }
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    func dismiss() {
        phase = .idle
    }

    // MARK: - NSURLSessionDownloadDelegate

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let fraction = totalBytesExpectedToWrite > 0
            ? min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
            : 0
        Task { @MainActor in
            if case .downloading = self.phase, let info = self.expectedInfo {
                self.phase = .downloading(fraction, info)
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("Headroom-download-\(UUID().uuidString).dmg")
        do {
            try FileManager.default.moveItem(at: location, to: tmp)
        } catch {
            Task { @MainActor in self.phase = .failed("Couldn't stage download.") }
            return
        }
        Task { @MainActor in
            self.downloadedURL = tmp
            self.applyDownload()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard error != nil else { return }
        Task { @MainActor in self.phase = .failed("Download failed.") }
    }

    // MARK: - Replace running app

    @MainActor
    private func applyDownload() {
        guard let dmg = downloadedURL else { return }
        downloadedURL = nil
        do {
            try replaceRunningApp(fromDMG: dmg)
            // If we got here, replacement has been staged; relaunch and quit.
            relaunch()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    @MainActor
    private func replaceRunningApp(fromDMG dmg: URL) throws {
        let ownURL = Bundle.main.bundleURL
        guard ownURL.pathExtension == "app" else {
            throw NSError(domain: "Headroom", code: 23, userInfo: [NSLocalizedDescriptionKey: "Not running from an app bundle."])
        }

        // Mount the DMG read-only.
        let mountPoint = FileManager.default.temporaryDirectory
            .appendingPathComponent("HeadroomUpdate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        let mountResult = shell("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-mountpoint", mountPoint.path])
        guard mountResult.status == 0 else {
            throw NSError(domain: "Headroom", code: 24, userInfo: [NSLocalizedDescriptionKey: "Couldn't mount the update."])
        }
        defer { _ = shell("/usr/bin/hdiutil", ["detach", mountPoint.path, "-quiet"]) }

        // Find the new app inside the DMG.
        let contents = try FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)
        guard let newApp = contents.first(where: { $0.pathExtension == "app" }) else {
            throw NSError(domain: "Headroom", code: 25, userInfo: [NSLocalizedDescriptionKey: "Update contains no app."])
        }

        // The running binary is in use; we can't delete it, but on macOS we
        // CAN rename a directory out of the way and then install the new one
        // in its place (Library/Application Support style).
        let backupURL = ownURL.appendingPathExtension("old-\(Int(Date().timeIntervalSince1970))")
        try FileManager.default.moveItem(at: ownURL, to: backupURL)
        do {
            try FileManager.default.copyItem(at: newApp, to: ownURL)
        } catch {
            // Roll back.
            try? FileManager.default.removeItem(at: ownURL)
            try? FileManager.default.moveItem(at: backupURL, to: ownURL)
            throw error
        }
        try? FileManager.default.removeItem(at: backupURL)
    }

    @MainActor
    private func relaunch() {
        let ownURL = Bundle.main.bundleURL
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", ownURL.path]
        try? proc.run()
        NSApp.terminate(nil)
    }

    private func notifyUpdateAvailable(_ info: UpdateInfo) {
        let content = UNMutableNotificationContent()
        content.title = "Headroom \(cleanTag(info.tagName)) is ready"
        content.body = "New version available. Open Headroom to update."
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "headroom-update-\(info.tagName)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }

    private func cleanTag(_ tag: String) -> String {
        tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }
}
