import Cocoa

final class SettingsWindowController: NSWindowController {

    convenience init() {
        let viewController = SettingsViewController()
        let window = NSWindow(contentViewController: viewController)
        window.title = "WakeyWakey Settings"
        window.styleMask = [.titled, .closable]

        // Size the window to fit all sections via Auto Layout; width stays fixed at 400.
        // Height never changes afterward: both the Jiggle and Lights boxes stay visible
        // (dimmed, not hidden) regardless of the selected mode.
        viewController.view.layoutSubtreeIfNeeded()
        let fittingSize = viewController.view.fittingSize
        window.setContentSize(NSSize(width: 400, height: fittingSize.height))
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
