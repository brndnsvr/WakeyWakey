import Cocoa
import IOKit
import IOKit.pwr_mgt
import ApplicationServices
import ServiceManagement
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var toggleItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!

    // Timer menu items (for dynamic title updates)
    private var timer1Item: NSMenuItem!
    private var timer2Item: NSMenuItem!
    private var timer3Item: NSMenuItem!

    private var isEnabled = false {
        didSet { updateUIForState() }
    }

    // Power management assertion to prevent idle sleep
    private var powerAssertion: IOPMAssertionID = 0

    // Idle/activity scheduling
    private var checkTimer: Timer?
    private var nextActivityDueAt: Date?
    private var timerExpiresAt: Date?  // For timed enable sessions

    // Settings reference and Combine subscriptions
    private let settings = Settings.shared
    private var cancellables = Set<AnyCancellable>()

    // Settings window
    private var settingsWindowController: SettingsWindowController?

    // Animation state
    private var isAnimating = false

    // Animation and detection configuration
    private struct AnimationConfig {
        static let minDuration: TimeInterval = 0.5
        static let maxDuration: TimeInterval = 1.0
        static let minSteps: Int = 4
        static let maxSteps: Int = 8
        static let minTotalDistance: CGFloat = 15
        static let maxTotalDistance: CGFloat = 35
        static let maxDeviationDegrees: CGFloat = 22
        static let centerBiasProbability: Int = 52

        // Mouse movement detection thresholds
        static let mouseMovementThreshold: CGFloat = 0.5    // Pixels to consider "moved"
        static let recentMovementWindow: TimeInterval = 2.0 // Seconds to track continuous movement
    }

    private enum PathType {
        case arc
        case zigzag
        case direct
    }

    private enum TimingPattern {
        case accelerateDecelerate
        case steady
        case quickPauseQuick
    }

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

        // Timer options (titles update dynamically from settings)
        timer1Item = NSMenuItem(title: "Enable for \(settings.formatDuration(settings.timerDuration1))", action: #selector(enableForTimer1), keyEquivalent: "")
        timer1Item.target = self
        menu.addItem(timer1Item)

        timer2Item = NSMenuItem(title: "Enable for \(settings.formatDuration(settings.timerDuration2))", action: #selector(enableForTimer2), keyEquivalent: "")
        timer2Item.target = self
        menu.addItem(timer2Item)

        timer3Item = NSMenuItem(title: "Enable for \(settings.formatDuration(settings.timerDuration3))", action: #selector(enableForTimer3), keyEquivalent: "")
        timer3Item.target = self
        menu.addItem(timer3Item)

        menu.addItem(NSMenuItem.separator())

        // Launch at Login toggle
        launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        updateLaunchAtLoginUI()

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // Accessibility permission check (for posting CGEvents)
        // Uses AXIsProcessTrustedWithOptions to auto-open System Settings if needed
        requestAccessibilityPermissionIfNeeded()

        // Start 1s heartbeat to detect idle and schedule actions when enabled
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }

        // Observe settings changes to update timer menu titles
        observeSettingsChanges()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up timer
        checkTimer?.invalidate()
        checkTimer = nil

        // Release power assertion
        endPreventingSleep()
    }

    private func observeSettingsChanges() {
        Publishers.CombineLatest3(
            settings.$timerDuration1,
            settings.$timerDuration2,
            settings.$timerDuration3
        )
        .dropFirst()  // Skip initial values
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            self?.updateTimerMenuTitles()
        }
        .store(in: &cancellables)
    }

    private func updateTimerMenuTitles() {
        timer1Item.title = "Enable for \(settings.formatDuration(settings.timerDuration1))"
        timer2Item.title = "Enable for \(settings.formatDuration(settings.timerDuration2))"
        timer3Item.title = "Enable for \(settings.formatDuration(settings.timerDuration3))"
    }

    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow()
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

    @objc private func enableForTimer1() { enableForDuration(settings.timerDuration1) }
    @objc private func enableForTimer2() { enableForDuration(settings.timerDuration2) }
    @objc private func enableForTimer3() { enableForDuration(settings.timerDuration3) }

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

    // MARK: - Accessibility Permission

    private func requestAccessibilityPermissionIfNeeded() {
        if !AXIsProcessTrusted() {
            // Log version for debugging permission issues across updates
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            print("WakeyWakey v\(version): Requesting Accessibility permission")

            // Prompt user by opening System Settings → Accessibility automatically
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    }

    // MARK: - Launch at Login

    @objc private func toggleLaunchAtLogin() {
        let isCurrentlyEnabled = SMAppService.mainApp.status == .enabled
        let operation = isCurrentlyEnabled ? "disable" : "enable"
        do {
            if isCurrentlyEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Launch at Login Error"
            alert.informativeText = "Could not \(operation) launch at login: \(error.localizedDescription)"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        updateLaunchAtLoginUI()
    }

    private func updateLaunchAtLoginUI() {
        let isEnabled = SMAppService.mainApp.status == .enabled
        launchAtLoginItem.state = isEnabled ? .on : .off
    }

    private func beginPreventingSleep() {
        if powerAssertion == 0 {
            // Use PreventUserIdleDisplaySleep to prevent both screensaver and display sleep
            // (NoIdleSleep only prevents system sleep, not screensaver)
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "WakeyWakey Active" as CFString,
                &powerAssertion
            )
            if result != kIOReturnSuccess {
                print("WakeyWakey: Failed to create power assertion (error: \(result))")
                powerAssertion = 0
            }
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
            // Cancel any in-progress animation
            if isAnimating { isAnimating = false }
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

        if idle < settings.idleThreshold {
            // User has been active recently; reset schedule so we fire immediately after next threshold
            // Cancel any in-progress animation
            if isAnimating { isAnimating = false }
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
        let threshold = AnimationConfig.mouseMovementThreshold
        let moved = abs(currentPos.x - lastPos.x) > threshold || abs(currentPos.y - lastPos.y) > threshold

        if moved {
            let now = Date()
            // If mouse moved, check if it's recent movement
            // This helps distinguish between our own jiggle movements and actual user movement
            if let lastMoveTime = lastMouseMoveTime {
                let timeSinceLastMove = now.timeIntervalSince(lastMoveTime)
                if timeSinceLastMove < AnimationConfig.recentMovementWindow {
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
            if timeSinceLastMove > settings.idleThreshold {
                lastMouseMoveTime = nil
            }
        }

        return false
    }

    private func scheduleNextActivity(afterNow now: Date) {
        let interval = settings.randomJiggleInterval
        nextActivityDueAt = now.addingTimeInterval(interval)
    }

    private func performActivity() {
        // Prevent overlapping animations
        guard !isAnimating else { return }

        // Get current mouse position directly in Quartz coordinates to avoid conversion issues
        guard let currentQuartzPos = CGEvent(source: nil)?.location else {
            // Fallback: get from NSEvent and convert
            let cocoaPoint = NSEvent.mouseLocation
            performActivityWithCocoaPoint(cocoaPoint)
            return
        }

        // Start animated jiggle
        performAnimatedJiggle(from: currentQuartzPos)
    }

    private func performAnimatedJiggle(from startPosition: CGPoint) {
        isAnimating = true

        // Get screen info
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            isAnimating = false
            return
        }

        let mainScreen = screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main ?? screens.first!
        let mainTopY = mainScreen.frame.maxY

        // Convert to Cocoa for screen detection
        let cocoaPoint = CGPoint(x: startPosition.x, y: mainTopY - startPosition.y)
        let currentScreen = screens.first(where: { $0.frame.contains(cocoaPoint) }) ?? mainScreen

        // Calculate final target using center bias
        let finalTarget = calculateFinalTarget(from: startPosition, screen: currentScreen, mainTopY: mainTopY)

        // Generate waypoints
        let waypoints = generateWaypoints(from: startPosition, to: finalTarget, screen: currentScreen, mainTopY: mainTopY)

        // Generate timing delays
        let delays = generateStepDelays(count: waypoints.count)

        // Execute animation sequence
        executeAnimationSequence(waypoints: waypoints, delays: delays)
    }

    private func calculateFinalTarget(from currentQuartzPos: CGPoint, screen: NSScreen, mainTopY: CGFloat) -> CGPoint {
        // Calculate total distance for this jiggle
        let totalDistance = CGFloat.random(in: AnimationConfig.minTotalDistance...AnimationConfig.maxTotalDistance)

        // Apply center bias
        let biasToCenter = Int.random(in: 1...100) <= AnimationConfig.centerBiasProbability

        var targetQuartz = currentQuartzPos

        if biasToCenter {
            // Move toward screen center
            let f = screen.frame
            let centerCocoa = CGPoint(x: f.midX, y: f.midY)
            let centerQuartz = CGPoint(x: centerCocoa.x, y: mainTopY - centerCocoa.y)

            let vx = centerQuartz.x - currentQuartzPos.x
            let vy = centerQuartz.y - currentQuartzPos.y
            let dist = sqrt(vx * vx + vy * vy)

            if dist >= 1.0 {
                let nx = vx / dist
                let ny = vy / dist
                targetQuartz.x += nx * min(totalDistance, dist)
                targetQuartz.y += ny * min(totalDistance, dist)
            } else {
                // At center - random direction
                let angle = CGFloat.random(in: 0...(2 * .pi))
                targetQuartz.x += cos(angle) * totalDistance
                targetQuartz.y += sin(angle) * totalDistance
            }
        } else {
            // Random direction
            let angle = CGFloat.random(in: 0...(2 * .pi))
            targetQuartz.x += cos(angle) * totalDistance
            targetQuartz.y += sin(angle) * totalDistance
        }

        // Clamp to screen
        return clampToScreen(point: targetQuartz, screen: screen, mainTopY: mainTopY)
    }

    private func generateWaypoints(from start: CGPoint, to end: CGPoint, screen: NSScreen, mainTopY: CGFloat) -> [CGPoint] {
        let stepCount = Int.random(in: AnimationConfig.minSteps...AnimationConfig.maxSteps)
        var waypoints: [CGPoint] = []

        // Calculate base direction vector
        let dx = end.x - start.x
        let dy = end.y - start.y
        let totalDist = sqrt(dx * dx + dy * dy)

        guard totalDist > 0 else {
            return [end]
        }

        // Unit vector toward target
        let ux = dx / totalDist
        let uy = dy / totalDist

        // Perpendicular vector for deviation
        let px = -uy
        let py = ux

        // Select path type
        let pathType = selectPathType()

        for i in 0..<stepCount {
            let progress = CGFloat(i + 1) / CGFloat(stepCount)

            // Base position along direct path
            var nextX = start.x + dx * progress
            var nextY = start.y + dy * progress

            // Apply deviation based on path type
            let deviation = calculateDeviation(pathType: pathType, stepIndex: i, totalSteps: stepCount)

            // Convert deviation to perpendicular offset
            let deviationDistance = (totalDist / CGFloat(stepCount)) * tan(deviation * .pi / 180)
            nextX += px * deviationDistance
            nextY += py * deviationDistance

            // Add small random variation
            let variation = CGFloat.random(in: 0.85...1.15)
            let currentPos = waypoints.last ?? start
            let adjustedX = currentPos.x + (nextX - currentPos.x) * variation
            let adjustedY = currentPos.y + (nextY - currentPos.y) * variation

            // Clamp to screen bounds
            let clamped = clampToScreen(point: CGPoint(x: adjustedX, y: adjustedY), screen: screen, mainTopY: mainTopY)
            waypoints.append(clamped)
        }

        // Ensure final waypoint is the target
        if let last = waypoints.last, last != end {
            waypoints[waypoints.count - 1] = clampToScreen(point: end, screen: screen, mainTopY: mainTopY)
        }

        return waypoints
    }

    private func selectPathType() -> PathType {
        let roll = Int.random(in: 1...100)
        if roll <= 40 { return .arc }
        if roll <= 75 { return .zigzag }
        return .direct
    }

    private func calculateDeviation(pathType: PathType, stepIndex: Int, totalSteps: Int) -> CGFloat {
        let maxDeviation = AnimationConfig.maxDeviationDegrees

        switch pathType {
        case .arc:
            // Sine-based arc: max deviation at middle
            let progress = CGFloat(stepIndex) / CGFloat(totalSteps - 1)
            let arcFactor = sin(progress * .pi)
            let direction: CGFloat = Bool.random() ? 1 : -1
            return direction * arcFactor * maxDeviation * CGFloat.random(in: 0.5...1.0)

        case .zigzag:
            // Alternating deviation
            let direction: CGFloat = stepIndex % 2 == 0 ? 1 : -1
            return direction * CGFloat.random(in: maxDeviation * 0.3...maxDeviation * 0.8)

        case .direct:
            // Small random wobble
            return CGFloat.random(in: -maxDeviation * 0.2...maxDeviation * 0.2)
        }
    }

    private func generateStepDelays(count: Int) -> [TimeInterval] {
        let totalDuration = TimeInterval.random(in: AnimationConfig.minDuration...AnimationConfig.maxDuration)

        // Select timing pattern
        let pattern = selectTimingPattern()

        var delays: [TimeInterval] = []
        let baseDelay = totalDuration / Double(count)

        for i in 0..<count {
            let progress = Double(i) / Double(max(1, count - 1))
            let multiplier = calculateTimingMultiplier(pattern: pattern, progress: progress)
            let delay = baseDelay * multiplier

            // Add small random variation (10-20%)
            let variation = Double.random(in: 0.9...1.1)
            delays.append(max(0.04, delay * variation))  // Minimum 40ms
        }

        // Normalize to match total duration
        let actualTotal = delays.reduce(0, +)
        if actualTotal > 0 {
            let scale = totalDuration / actualTotal
            delays = delays.map { $0 * scale }
        }

        return delays
    }

    private func selectTimingPattern() -> TimingPattern {
        let roll = Int.random(in: 1...100)
        if roll <= 50 { return .accelerateDecelerate }
        if roll <= 80 { return .steady }
        return .quickPauseQuick
    }

    private func calculateTimingMultiplier(pattern: TimingPattern, progress: Double) -> Double {
        switch pattern {
        case .accelerateDecelerate:
            // Slow at start and end, fast in middle
            let sineFactor = sin(progress * .pi)
            return sineFactor > 0.1 ? 1.0 / sineFactor : 2.0

        case .steady:
            return 1.0

        case .quickPauseQuick:
            // Fast at start, slow in middle, fast at end
            let midDistance = abs(progress - 0.5) * 2
            return 0.5 + (1 - midDistance) * 1.5
        }
    }

    private func executeAnimationSequence(waypoints: [CGPoint], delays: [TimeInterval]) {
        guard !waypoints.isEmpty else {
            isAnimating = false
            return
        }

        var cumulativeDelay: TimeInterval = 0

        for (index, waypoint) in waypoints.enumerated() {
            let delay = index < delays.count ? delays[index] : 0.1
            cumulativeDelay += delay

            DispatchQueue.main.asyncAfter(deadline: .now() + cumulativeDelay) { [weak self] in
                guard let self = self else { return }

                // Check if we should abort (e.g., user became active or disabled)
                guard self.isAnimating && self.isEnabled else {
                    self.isAnimating = false
                    return
                }

                // Post the mouse move event
                if let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: waypoint, mouseButton: .left) {
                    move.post(tap: .cghidEventTap)
                }

                // Mark animation complete after last waypoint
                if index == waypoints.count - 1 {
                    self.isAnimating = false
                }
            }
        }
    }

    private func clampToScreen(point: CGPoint, screen: NSScreen, mainTopY: CGFloat) -> CGPoint {
        let f = screen.frame
        let minQuartzY = mainTopY - f.maxY
        let maxQuartzY = mainTopY - f.minY

        return CGPoint(
            x: max(f.minX, min(point.x, f.maxX - 1)),
            y: max(minQuartzY, min(point.y, maxQuartzY - 1))
        )
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
