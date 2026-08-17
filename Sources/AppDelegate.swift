import AppKit
import UserNotifications

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let fleet = FleetModel()
    private let notificationForwarder = NotificationForwarder()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var panel: PanelController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = notificationForwarder

        panel = PanelController(fleet: fleet)
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = panel

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        fleet.onChange = { [weak self] in
            self?.refreshChrome()
        }
        fleet.start()
        refreshChrome()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        panel.reload()
        popover.contentSize = panel.preferredContentSize
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func refreshChrome() {
        statusItem.button?.title = " " + Formatters.statusTitle(fleet)
        statusItem.button?.image = dot(Palette.pressure(fleet.worstPressure))
        statusItem.button?.imagePosition = .imageLeft
        statusItem.button?.toolTip = fleet.hosts.isEmpty
            ? "Headroom — add a machine"
            : "Headroom, \(fleet.hosts.count) machines"
        if popover.isShown {
            panel.reload()
            popover.contentSize = panel.preferredContentSize
        }
    }

    private func dot(_ color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.6, dy: 0.6)).fill()
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
