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
    private var timerExpiresAt: Date?  // For timed enable sessions
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

        // Timer options
        let timer1h = NSMenuItem(title: "Enable for 1 hour", action: #selector(enableFor1Hour), keyEquivalent: "")
        timer1h.target = self
        menu.addItem(timer1h)

        let timer4h = NSMenuItem(title: "Enable for 4 hours", action: #selector(enableFor4Hours), keyEquivalent: "")
        timer4h.target = self
        menu.addItem(timer4h)

        let timer8h = NSMenuItem(title: "Enable for 8 hours", action: #selector(enableFor8Hours), keyEquivalent: "")
        timer8h.target = self
        menu.addItem(timer8h)

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
        timerExpiresAt = nil  // Clear any active timer on manual toggle
        isEnabled.toggle()
        if isEnabled {
            beginPreventingSleep()
        } else {
            endPreventingSleep()
            nextActivityDueAt = nil
        }
    }

    // MARK: - Timer-based enable

    @objc private func enableFor1Hour() { enableForDuration(3600) }
    @objc private func enableFor4Hours() { enableForDuration(14400) }
    @objc private func enableFor8Hours() { enableForDuration(28800) }

    private func enableForDuration(_ seconds: TimeInterval) {
        timerExpiresAt = Date().addingTimeInterval(seconds)
        if !isEnabled {
            isEnabled = true
            beginPreventingSleep()
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
        // Check if timer expired
        if let expiresAt = timerExpiresAt, Date() >= expiresAt {
            timerExpiresAt = nil
            if isEnabled {
                isEnabled = false
                endPreventingSleep()
                nextActivityDueAt = nil
            }
            return
        }

        guard isEnabled else { return }

        // Check if Universal Control might be active by detecting cursor position changes
        // even when no local events are registered
        let currentMousePos = NSEvent.mouseLocation
        if hasMouseMovedSinceLastCheck(currentPos: currentMousePos) {
            // Mouse has moved, consider user active even if no HID events
            nextActivityDueAt = nil
            return
        }

        // Determine seconds since last user input event
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

    // Track mouse position to detect Universal Control movement
    private var lastKnownMousePos: CGPoint?
    private var lastMouseMoveTime: Date?

    private func hasMouseMovedSinceLastCheck(currentPos: CGPoint) -> Bool {
        defer {
            lastKnownMousePos = currentPos
        }

        guard let lastPos = lastKnownMousePos else {
            // First check, store position
            return false
        }

        // Check if mouse position has changed
        let moved = abs(currentPos.x - lastPos.x) > 0.5 || abs(currentPos.y - lastPos.y) > 0.5

        if moved {
            let now = Date()
            // If mouse moved, check if it's recent movement (within last 2 seconds)
            // This helps distinguish between our own jiggle movements and actual user movement
            if let lastMoveTime = lastMouseMoveTime {
                let timeSinceLastMove = now.timeIntervalSince(lastMoveTime)
                if timeSinceLastMove < 2.0 {
                    // Recent continuous movement, likely user activity
                    lastMouseMoveTime = now
                    return true
                }
            }
            lastMouseMoveTime = now
            return true
        }

        // Check if we've been still too long (reset movement tracking after idle period)
        if let lastMoveTime = lastMouseMoveTime {
            let timeSinceLastMove = Date().timeIntervalSince(lastMoveTime)
            if timeSinceLastMove > idleThreshold {
                lastMouseMoveTime = nil
            }
        }

        return false
    }

    private func scheduleNextActivity(afterNow now: Date) {
        let interval = TimeInterval(Int.random(in: Int(minInterval)...Int(maxInterval)))
        nextActivityDueAt = now.addingTimeInterval(interval)
    }

    private func performActivity() {
        // Get current mouse position directly in Quartz coordinates to avoid conversion issues
        guard let currentQuartzPos = CGEvent(source: nil)?.location else {
            // Fallback: get from NSEvent and convert
            let cocoaPoint = NSEvent.mouseLocation
            performActivityWithCocoaPoint(cocoaPoint)
            return
        }

        // Work directly in Quartz coordinates (origin top-left)
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        // Find the main screen for coordinate system reference
        let mainScreen = screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main ?? screens.first!
        let mainTopY = mainScreen.frame.maxY

        // Convert current Quartz position to Cocoa for screen detection
        let cocoaPoint = CGPoint(x: currentQuartzPos.x, y: mainTopY - currentQuartzPos.y)

        // Find current screen
        let currentScreen = screens.first(where: { $0.frame.contains(cocoaPoint) }) ?? mainScreen

        // Calculate movement
        let step = CGFloat(Int.random(in: 11...23))
        let biasToCenter = Int.random(in: 1...100) <= 52

        var targetQuartz = currentQuartzPos

        if biasToCenter {
            // Convert screen center to Quartz coordinates
            let f = currentScreen.frame
            let centerCocoa = CGPoint(x: f.midX, y: f.midY)
            let centerQuartz = CGPoint(x: centerCocoa.x, y: mainTopY - centerCocoa.y)

            let vx = centerQuartz.x - currentQuartzPos.x
            let vy = centerQuartz.y - currentQuartzPos.y
            let dist = sqrt(vx*vx + vy*vy)

            if dist >= 1.0 {
                let nx = vx / dist
                let ny = vy / dist
                targetQuartz.x += nx * min(step, dist)
                targetQuartz.y += ny * min(step, dist)
            } else {
                // Already at center, small random move
                targetQuartz.x += (Bool.random() ? 1 : -1) * CGFloat(Int.random(in: 11...23))
                targetQuartz.y += (Bool.random() ? 1 : -1) * CGFloat(Int.random(in: 11...23))
            }
        } else {
            // Random small move
            targetQuartz.x += (Bool.random() ? 1 : -1) * CGFloat(Int.random(in: 11...23))
            targetQuartz.y += (Bool.random() ? 1 : -1) * CGFloat(Int.random(in: 11...23))
        }

        // Clamp to current screen bounds (convert bounds to Quartz)
        let f = currentScreen.frame
        let minQuartzY = mainTopY - f.maxY
        let maxQuartzY = mainTopY - f.minY

        targetQuartz.x = max(f.minX, min(targetQuartz.x, f.maxX - 1))
        targetQuartz.y = max(minQuartzY, min(targetQuartz.y, maxQuartzY - 1))

        // Post the mouse move event
        if let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: targetQuartz, mouseButton: .left) {
            move.post(tap: .cghidEventTap)
        }
    }

    private func performActivityWithCocoaPoint(_ cocoaPoint: CGPoint) {
        // Fallback method using original logic
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let mainScreen = screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main ?? screens.first!
        let mainTopY = mainScreen.frame.maxY
        let currentScreen = screens.first(where: { $0.frame.contains(cocoaPoint) }) ?? mainScreen

        let step = CGFloat(Int.random(in: 11...23))
        var target = cocoaPoint

        // Simple random move to avoid complexity in fallback
        target.x += (Bool.random() ? 1 : -1) * step
        target.y += (Bool.random() ? 1 : -1) * step

        // Clamp to screen
        let f = currentScreen.frame
        target.x = max(f.minX, min(target.x, f.maxX - 1))
        target.y = max(f.minY, min(target.y, f.maxY - 1))

        let newQuartz = CGPoint(x: target.x, y: mainTopY - target.y)

        if let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: newQuartz, mouseButton: .left) {
            move.post(tap: .cghidEventTap)
        }
    }
}
