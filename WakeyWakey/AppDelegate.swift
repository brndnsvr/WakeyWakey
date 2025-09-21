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

        // Determine seconds since last user input event (Option A):
        // Take the minimum across explicit keyboard and mouse event types for robustness
        let eventTypes: [CGEventType] = [
            .mouseMoved, .leftMouseDown, .leftMouseDragged,
            .rightMouseDown, .rightMouseDragged,
            .otherMouseDown, .otherMouseDragged,
            .scrollWheel, .keyDown, .keyUp, .flagsChanged
        ]
        let idle = eventTypes
            .map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }
            .min() ?? 0.0

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
        // Move mouse a small distance; 52% of the time bias toward the center of the current screen
        let cocoaPoint = NSEvent.mouseLocation

        let screens = NSScreen.screens

        // Determine the primary (menu bar) screen in Cocoa coordinates (origin at 0,0)
        let mainScreen = screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main ?? screens.first!
        let mainTopY = mainScreen.frame.maxY

        // Determine the screen currently under the cursor; fallback to main if unknown
        let currentScreen = screens.first(where: { $0.frame.contains(cocoaPoint) }) ?? NSScreen.main ?? mainScreen

        let step = CGFloat(Int.random(in: 11...23))
        let biasToCenter = Int.random(in: 1...100) <= 52

        var target = CGPoint(x: cocoaPoint.x, y: cocoaPoint.y)
        if biasToCenter {
            // Step toward the center of the current screen
            let f = currentScreen.frame
            let center = CGPoint(x: f.midX, y: f.midY)
            let vx = center.x - cocoaPoint.x
            let vy = center.y - cocoaPoint.y
            let dist = sqrt(vx*vx + vy*vy)
            if dist >= 1.0 {
                let nx = vx / dist
                let ny = vy / dist
                target.x += nx * min(step, dist)
                target.y += ny * min(step, dist)
            } else {
                // Already at/near center; fall back to a random small move
                let dx = (Bool.random() ? 1 : -1) * CGFloat(Int.random(in: 11...23))
                let dy = (Bool.random() ? 1 : -1) * CGFloat(Int.random(in: 11...23))
                target.x += dx
                target.y += dy
            }
        } else {
            // Random small move in any direction
            let dx = (Bool.random() ? 1 : -1) * CGFloat(Int.random(in: 11...23))
            let dy = (Bool.random() ? 1 : -1) * CGFloat(Int.random(in: 11...23))
            target.x += dx
            target.y += dy
        }

        // Clamp within the current screen’s frame to avoid jumping across displays or into gaps
        let f = currentScreen.frame
        target.x = max(f.minX, min(target.x, f.maxX - 1))
        target.y = max(f.minY, min(target.y, f.maxY - 1))

        // Convert Cocoa (origin bottom-left of main screen) to Quartz global coords (origin top-left of main screen)
        let newQuartz = CGPoint(x: target.x, y: mainTopY - target.y)

        if let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: newQuartz, mouseButton: .left) {
            move.post(tap: .cghidEventTap)
        }
    }
}
