import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let fleet = FleetModel()
    private let notificationForwarder = NotificationForwarder()
    private var statusItem: NSStatusItem?
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mine = ProcessInfo.processInfo.processIdentifier
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: "app.headroom.mac")
        where app.processIdentifier != mine {
            app.forceTerminate()
        }

        NSApp.setActivationPolicy(.regular)
        UNUserNotificationCenter.current().delegate = notificationForwarder

        let host = NSHostingController(rootView: RootView(fleet: fleet))
        window = NSWindow(contentViewController: host)
        window.title = "Headroom"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.insert(.resizable)
        window.backgroundColor = NSColor(srgbRed: 0.043, green: 0.067, blue: 0.102, alpha: 1)
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 460, height: 640))
        window.minSize = NSSize(width: 420, height: 520)
        window.center()
        window.makeKeyAndOrderFront(nil)

        installStatusItem()
        fleet.onChange = { [weak self] in
            self?.refreshChrome()
        }
        fleet.start()
        refreshChrome()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func installStatusItem() {
        if statusItem != nil { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.isVisible = true
        item.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        item.button?.title = "Headroom"
        item.button?.toolTip = "Headroom"
        item.button?.target = self
        item.button?.action = #selector(toggleWindow)
        statusItem = item
    }

    @objc private func toggleWindow() {
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func refreshChrome() {
        installStatusItem()
        statusItem?.isVisible = true
        statusItem?.button?.title = Formatters.statusTitle(fleet)
        statusItem?.button?.image = dot(Palette.pressure(fleet.worstPressure))
        statusItem?.button?.imagePosition = .imageLeft
    }

    private func dot(_ color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 10, height: 10), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}

final class NotificationForwarder: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
