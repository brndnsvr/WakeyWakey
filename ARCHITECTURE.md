# HOW_IT_WORKS.md

WakeyWakey • Internal Algorithms and Control Flow (Launch → Quit)

This document explains, in near–pseudo-code, how WakeyWakey operates from process start until quit. It breaks down the main algorithms, timers, event handling, multi‑monitor logic, and all critical if/then branches.


## High‑level overview
- App type: AppKit menu bar application (no Dock icon; LSUIElement=true)
- Entry point: main.swift constructs NSApplication and installs AppDelegate
- AppDelegate responsibilities:
  - Configure status bar item + menu (Enable/Disable, Quit)
  - Enforce app policy (accessory, no Dock)
  - Manage Accessibility permission prompt
  - Maintain active/inactive state, Power Management assertion, timers
  - Idle detection (keyboard + mouse) and activity scheduling
  - Generate subtle mouse events (jiggles) with a 52% center bias
- External effects:
  - Prevents system idle sleep while enabled (IOPM assertion)
  - Generates small mouse move CGEvents to keep presence “green”


## Lifecycle summary
1) Process starts → main.swift runs → NSApplication.shared → AppDelegate() → app.run()
2) AppDelegate.init sets NSApp.setActivationPolicy(.accessory)
3) applicationDidFinishLaunching:
   - Create NSStatusItem and configure icon, target/action, and menu
   - Show Accessibility permission prompt if needed
   - Start 1s heartbeat timer (tick())
4) User toggles Enable:
   - If enabled: create IOPM no-idle-sleep assertion; begin jiggle scheduling
   - If disabled: release assertion; stop scheduling
5) Heartbeat (tick) executes every second:
   - Measure idle time using minimum across explicit keyboard and mouse events
   - If user is active (< threshold), do not jiggle and reset schedule
   - If idle ≥ threshold, perform or schedule jiggle at randomized intervals
6) performActivity generates a small mouse move event
   - 52% of jiggles: step toward center of current screen
   - 48% of jiggles: random small dx/dy move
   - Clamp within current screen; convert to Quartz global; post event
7) User selects Quit → NSApplication.terminate


## Detailed control flows (pseudo‑code)

### Entry point and activation policy
```swift path=null start=null
// main.swift
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

// AppDelegate.init
NSApp.setActivationPolicy(.accessory)  // ensures no Dock icon for menu bar app
```


### Launch: status item, menu, accessibility, heartbeat
```swift path=null start=null
func applicationDidFinishLaunching(_:) {
  // status bar
  statusItem = NSStatusBar.system.statusItem(withLength: variable)
  statusItem.button.image = SF Symbol "cup.and.saucer" (template)
  statusItem.button.target = self
  statusItem.button.action = #selector(statusItemClicked)

  // menu
  menu = NSMenu()
  toggleItem = NSMenuItem("Enable", action: #selector(toggleEnabled))
  menu.addItem(toggleItem)
  menu.addItem(.separator())
  menu.addItem(NSMenuItem("Quit", action: #selector(NSApp.terminate(_:))))
  statusItem.menu = menu

  // Optional: Accessibility permission prompt
  if !AXIsProcessTrusted() { show informational alert }

  // heartbeat (1 Hz)
  checkTimer = Timer.scheduledTimer(every: 1s, repeats: true) { tick() }
}
```


### Enable/Disable toggle and power assertion
```swift path=null start=null
@objc func toggleEnabled() {
  isEnabled.toggle()
  if isEnabled {
    // Prevent idle sleep (system sleep) while active
    IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep, levelOn, name: "WakeyWakey", &powerAssertion)
  } else {
    // Stop activity and allow idle sleep again
    if powerAssertion != 0 { IOPMAssertionRelease(powerAssertion); powerAssertion = 0 }
    nextActivityDueAt = nil
  }
  updateUIForState()  // (Enable ↔ Disable title, cup icon fill ↔ outline)
}
```


### Idle detection and scheduling (tick)
```swift path=null start=null
func tick() {
  if !isEnabled { return }

  // Option A (robust across stacks like DisplayLink):
  // Take the minimum seconds since last event across explicit keyboard + mouse events
  let types = [mouseMoved, leftDown, leftDragged, rightDown, rightDragged,
               otherDown, otherDragged, scrollWheel, keyDown, keyUp, flagsChanged]
  let idle = min(types.map { CGEventSource.secondsSinceLastEventType(.hidSystemState, $0) })

  if idle < idleThresholdSeconds (42) {
    // IF user is active THEN do nothing, clear schedule, and return
    nextActivityDueAt = nil
    return
  }

  let now = Date()
  if nextActivityDueAt == nil {
    // IF first time crossing idle threshold THEN perform immediately and schedule next
    performActivity()
    nextActivityDueAt = now + random(42...79) seconds
    return
  }

  if now >= nextActivityDueAt! {
    // IF due time reached THEN perform and schedule next
    performActivity()
    nextActivityDueAt = now + random(42...79) seconds
  }
}
```


### Activity generation (multi‑monitor aware, 52% center bias)
```swift path=null start=null
func performActivity() {
  // Current pointer in Cocoa global (origin: bottom‑left of main display)
  let current = NSEvent.mouseLocation

  // Screens
  let screens = NSScreen.screens
  let mainScreen = screens.first(where: { $0.frame.origin == .zero })
                 ?? NSScreen.main ?? screens.first!
  let currentScreen = screens.first(where: { $0.frame.contains(current) })
                    ?? NSScreen.main ?? mainScreen

  // Random small step length
  let step = randomInt(11...23)

  // With probability 52% → step toward center of current screen; else random dx/dy
  let biasToCenter = randomInt(1...100) <= 52
  var target = current
  if biasToCenter {
    let f = currentScreen.frame
    let center = (x: f.midX, y: f.midY)
    let vec = (x: center.x - current.x, y: center.y - current.y)
    let dist = hypot(vec.x, vec.y)
    if dist >= 1 {
      let nx = vec.x / dist, ny = vec.y / dist
      target.x += nx * min(step, dist)
      target.y += ny * min(step, dist)
    } else {
      // Already at/near center → fallback to random move
      target.x += randomSign() * randomInt(11...23)
      target.y += randomSign() * randomInt(11...23)
    }
  } else {
    target.x += randomSign() * randomInt(11...23)
    target.y += randomSign() * randomInt(11...23)
  }

  // Clamp to current screen to avoid crossing displays or empty gaps
  let f = currentScreen.frame
  target.x = clamp(target.x, f.minX, f.maxX - 1)
  target.y = clamp(target.y, f.minY, f.maxY - 1)

  // Convert to Quartz global (origin: top‑left of main display)
  let mainTopY = mainScreen.frame.maxY
  let quartz = CGPoint(x: target.x, y: mainTopY - target.y)

  // Post a single, subtle mouseMoved CGEvent
  CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: quartz, mouseButton: .left)
    ?.post(tap: .cghidEventTap)
}
```


### Status indicator logic (icon + menu label)
```swift path=null start=null
func updateUIForState() {
  toggleItem.title = isEnabled ? "Disable" : "Enable"
  statusItem.button.image = isEnabled ? SF "cup.and.saucer.fill" : SF "cup.and.saucer"
}
```


### Quit
```swift path=null start=null
// Menu item: Quit WakeyWakey → NSApplication.terminate(self)
// OS tears down process; any held assertions are released by the process ending
// (When disabling via menu before quit, assertion is explicitly released.)
```


## State machine (simplified)
- States: Disabled, EnabledIdleBelowThreshold, EnabledIdleAboveThresholdWaiting, EnabledDueNow
- Events: ToggleEnable, ToggleDisable, Heartbeat(now), Quit

- Disabled
  - on ToggleEnable → EnabledIdleBelowThreshold
  - on Heartbeat → stay
- EnabledIdleBelowThreshold
  - on Heartbeat if idle < 42 → stay
  - on Heartbeat if idle ≥ 42 → EnabledDueNow (perform immediately)
  - on ToggleDisable → Disabled
- EnabledDueNow
  - action performActivity; schedule next in 42–79s → EnabledIdleAboveThresholdWaiting
  - on ToggleDisable → Disabled
- EnabledIdleAboveThresholdWaiting
  - on Heartbeat if idle < 42 → EnabledIdleBelowThreshold (cancel schedule)
  - on Heartbeat if now ≥ due → EnabledDueNow
  - on ToggleDisable → Disabled
- Quit at any point terminates process


## Multi‑monitor considerations
- Cocoa global coordinates (NSEvent.mouseLocation, NSScreen.frame) use origin at bottom‑left of the main display.
- Quartz global coordinates (CGEvent mouseCursorPosition) use origin at top‑left of the main display.
- We:
  - Identify the current screen containing the pointer for clamping
  - Anchor Y‑flip to main display top edge (mainTopY − cocoaY)
  - Avoid union‑based flips that can misplace the cursor when displays are arranged above/below/left/right
- DisplayLink: Virtual/USB graphics stacks are supported by virtue of using global input events + clamped screen frames.


## Idle detection details (Option A)
- Measure idle as the minimum seconds since last event across:
  - Mouse: mouseMoved, left/right/other down, their dragged variants, scrollWheel
  - Keyboard: keyDown, keyUp, flagsChanged
- Reasoning:
  - Some stacks (e.g., virtual displays) may not reflect all activity in a single “any event” counter.
  - Taking the min across explicit types reduces false idles while the user is typing or scrolling.
- Alternatives (if necessary in future):
  - Event Tap: passively observe real user events to update lastUserInputAt
  - IOKit HIDIdleTime: read system‑level idle in nanoseconds from IORegistry


## Timings and parameters
- idleThreshold: 42 seconds
- schedule window: random 42–79 seconds between jiggles
- step size per jiggle: 11–23 pixels
- center bias probability: 52%


## Error handling and prompts
- Accessibility: If !AXIsProcessTrusted, show an alert instructing the user to grant permission and relaunch.
- Gatekeeper: First launch on a different Mac may require Control‑click → Open.


## Non‑goals (current)
- No keyboard event generation (F‑keys) to remain stealthy and app‑agnostic
- No app‑specific heuristics (e.g., Teams targeting)
- No preferences UI (future roadmap)
