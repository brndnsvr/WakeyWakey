import Cocoa
import IOKit
import IOKit.pwr_mgt
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var toggleItem: NSMenuItem!

    private var isEnabled = false {
        didSet { updateUIForState() }
    }

    // Power management assertion to prevent idle sleep
    private var powerAssertion: IOPMAssertionID = 0

    // Idle/activity scheduling
    private var checkTimer: Timer?
    private var nextActivityDueAt: Date?
    private let idleThreshold: TimeInterval = 42
    private let minInterval: TimeInterval = 42
    private let maxInterval: TimeInterval = 79

    override init() {
        super.init()
        // MUST be in init for proper menu bar app behavior
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Status item setup
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: "WakeyWakey")
            image?.isTemplate = true
            button.image = image
            button.target = self
            button.action = #selector(statusItemClicked)
        }

        // Menu
        let menu = NSMenu()
        toggleItem = NSMenuItem(title: "Enable", action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // Accessibility permission check (for posting CGEvents)
        if !AXIsProcessTrusted() {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "WakeyWakey needs Accessibility permission to post input events. Go to System Settings → Privacy & Security → Accessibility and add WakeyWakey. Restart the app after granting."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }

        // Start 1s heartbeat to detect idle and schedule actions when enabled
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    @objc private func statusItemClicked() {
        if let menu = statusItem.menu {
            statusItem.popUpMenu(menu) // works even though deprecated
        }
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        if isEnabled {
            beginPreventingSleep()
        } else {
            endPreventingSleep()
            nextActivityDueAt = nil
        }
    }

    private func updateUIForState() {
        toggleItem.title = isEnabled ? "Disable" : "Enable"
        if let button = statusItem.button {
            let symbol = isEnabled ? "cup.and.saucer.fill" : "cup.and.saucer"
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "WakeyWakey")
            image?.isTemplate = true
            button.image = image
        }
    }

    private func beginPreventingSleep() {
        if powerAssertion == 0 {
            IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoIdleSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "WakeyWakey Active" as CFString,
                &powerAssertion
            )
        }
    }

    private func endPreventingSleep() {
        if powerAssertion != 0 {
            IOPMAssertionRelease(powerAssertion)
            powerAssertion = 0
        }
    }

    private func tick() {
        guard isEnabled else { return }

        // Determine seconds since last user input event
        let idle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .null)

        if idle < idleThreshold {
            // User has been active recently; reset schedule so we fire immediately after next threshold
            nextActivityDueAt = nil
            return
        }

        // We are past the idle threshold
        let now = Date()
        if nextActivityDueAt == nil {
            // First time past the threshold → perform immediately
            performActivity()
            scheduleNextActivity(afterNow: now)
            return
        }

        if let due = nextActivityDueAt, now >= due {
            performActivity()
            scheduleNextActivity(afterNow: now)
        }
    }

    private func scheduleNextActivity(afterNow now: Date) {
        let interval = TimeInterval(Int.random(in: Int(minInterval)...Int(maxInterval)))
        nextActivityDueAt = now.addingTimeInterval(interval)
    }

    private func performActivity() {
        // Move mouse a small random distance in a random direction (visible but subtle)
        // Choose random deltas between 11 and 23 pixels for both axes, with random signs
        let cocoaPoint = NSEvent.mouseLocation

        let screens = NSScreen.screens

        // Determine the primary (menu bar) screen in Cocoa coordinates (origin at 0,0)
        let mainScreen = screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main ?? screens.first!
        let mainTopY = mainScreen.frame.maxY

        // Determine the screen currently under the cursor; fallback to main if unknown
        let currentScreen = screens.first(where: { $0.frame.contains(cocoaPoint) }) ?? NSScreen.main ?? mainScreen

        let dxMagnitude = CGFloat(Int.random(in: 11...23))
        let dyMagnitude = CGFloat(Int.random(in: 11...23))
        let dx = Bool.random() ? dxMagnitude : -dxMagnitude
        let dy = Bool.random() ? dyMagnitude : -dyMagnitude

        var newCocoa = NSPoint(x: cocoaPoint.x + dx, y: cocoaPoint.y + dy)

        // Clamp within the current screen’s frame to avoid jumping across displays or into gaps
        let f = currentScreen.frame
        newCocoa.x = max(f.minX, min(newCocoa.x, f.maxX - 1))
        newCocoa.y = max(f.minY, min(newCocoa.y, f.maxY - 1))

        // Convert Cocoa (origin bottom-left of main screen) to Quartz global coords (origin top-left of main screen)
        let newQuartz = CGPoint(x: newCocoa.x, y: mainTopY - newCocoa.y)

        if let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: newQuartz, mouseButton: .left) {
            move.post(tap: .cghidEventTap)
        }
    }
}
