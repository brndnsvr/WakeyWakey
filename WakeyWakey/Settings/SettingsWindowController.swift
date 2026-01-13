import Cocoa

final class SettingsWindowController: NSWindowController {

    convenience init() {
        let viewController = SettingsViewController()
        let window = NSWindow(contentViewController: viewController)
        window.title = "WakeyWakey Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 400, height: 350))
        window.center()

        // Prevent resizing
        window.styleMask.remove(.resizable)

        self.init(window: window)
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
