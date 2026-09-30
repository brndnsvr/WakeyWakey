import Cocoa

final class SettingsWindowController: NSWindowController {

    convenience init() {
        let viewController = SettingsViewController()
        let window = NSWindow(contentViewController: viewController)
        window.title = "WakeyWakey Settings"
        window.styleMask = [.titled, .closable]

        // Size the window to fit all sections via Auto Layout; the view controller
        // fixes the width. Mode changes never change the height: both the Jiggle and
        // Lights boxes stay visible (dimmed, not hidden) regardless of the selected
        // mode. Only adding or removing a schedule block refits it.
        viewController.view.layoutSubtreeIfNeeded()
        window.setContentSize(viewController.view.fittingSize)
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
