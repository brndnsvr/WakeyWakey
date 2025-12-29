# CLAUDE.md

## Project Overview

WakeyWakey is a Swift/AppKit macOS menu bar application that prevents system idle sleep by simulating subtle mouse movements. It runs as a menu bar app with no Dock icon (LSUIElement=true).

**Tech Stack**: Swift, AppKit, IOKit, XcodeGen
**Target**: macOS 15.0+, arm64

## Quick Commands

```bash
# One-time setup
brew install xcodegen
./scripts/generate_project.sh

# Build and run (Debug)
./scripts/build_debug.sh
./scripts/install.sh
./scripts/run.sh

# Kill the app
./scripts/kill.sh

# Release build
./scripts/build_release.sh
cp -R build/Build/Products/Release/WakeyWakey.app /Applications/
```

## Project Structure

```
WakeyWakey/
├── WakeyWakey/
│   ├── main.swift              # Required entry point for menu bar apps
│   ├── AppDelegate.swift       # All app logic (menu, timers, jiggle)
│   └── Resources/Info.plist    # LSUIElement=true
├── scripts/                    # Build automation
├── project.yml                 # XcodeGen configuration
└── README.md                   # User documentation
```

## Critical Implementation Patterns

### Menu Bar App Setup (MUST follow this pattern)

```swift
// main.swift - REQUIRED for menu bar apps
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

// AppDelegate.init - MUST set policy here, NOT in applicationDidFinishLaunching
override init() {
    super.init()
    NSApp.setActivationPolicy(.accessory)
}
```

### Status Item Configuration

```swift
func applicationDidFinishLaunching(_:) {
    statusItem = NSStatusBar.system.statusItem(withLength: .variable)
    if let button = statusItem.button {
        button.image = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: nil)
        button.image?.isTemplate = true  // For dark mode
        button.target = self
        button.action = #selector(statusItemClicked)
    }
    statusItem.menu = menu  // Must assign menu
}

@objc func statusItemClicked() {
    statusItem.popUpMenu(menu)  // Deprecated but working
}
```

### Power Management

```swift
// Prevent idle sleep
IOPMAssertionCreateWithName(
    kIOPMAssertionTypeNoIdleSleep as CFString,
    IOPMAssertionLevel(kIOPMAssertionLevelOn),
    "WakeyWakey" as CFString,
    &powerAssertion
)

// Release when disabled
IOPMAssertionRelease(powerAssertion)
```

## Architecture

### Lifecycle
1. `main.swift` → `NSApplication.shared` → `AppDelegate()` → `app.run()`
2. `AppDelegate.init()` sets `.accessory` policy (no Dock icon)
3. `applicationDidFinishLaunching`: status item, menu, accessibility check, 1Hz timer
4. User toggles Enable → create/release IOPM assertion, start/stop scheduling
5. `tick()` runs every second → idle detection → schedule/perform jiggles

### Idle Detection (Option A - robust)
```swift
let types: [CGEventType] = [.mouseMoved, .leftMouseDown, .leftMouseDragged,
    .rightMouseDown, .rightMouseDragged, .otherMouseDown, .otherMouseDragged,
    .scrollWheel, .keyDown, .keyUp, .flagsChanged]
let idle = types.map { CGEventSource.secondsSinceLastEventType(.hidSystemState, $0) }.min()!
```
- Takes minimum across explicit event types (handles DisplayLink/virtual display stacks)
- Threshold: 42 seconds

### Jiggle Algorithm
- **Step size**: 11-23 pixels random
- **Center bias**: 52% of jiggles step toward screen center, 48% random direction
- **Clamping**: Constrain to current screen bounds
- **Interval**: 42-79 seconds random between jiggles

### Multi-Monitor Coordinate Conversion
```swift
// Cocoa: origin at bottom-left of main display
let current = NSEvent.mouseLocation

// Find current screen
let currentScreen = NSScreen.screens.first { $0.frame.contains(current) }

// Quartz: origin at top-left of main display
let mainTopY = mainScreen.frame.maxY
let quartz = CGPoint(x: target.x, y: mainTopY - target.y)

// Post event
CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: quartz, mouseButton: .left)?
    .post(tap: .cghidEventTap)
```

### State Machine
- **Disabled**: waiting for user to enable
- **EnabledIdleBelowThreshold**: user active (idle < 42s), no jiggles
- **EnabledDueNow**: perform jiggle, schedule next 42-79s
- **EnabledIdleAboveThresholdWaiting**: waiting for next scheduled jiggle

## Anti-Patterns (Do NOT)

### Menu Bar
- Don't remove `button.target`/`button.action` - menu won't respond
- Don't use `statusItem.button?.performClick(nil)` - causes recursion
- Don't put `setActivationPolicy(.accessory)` in `applicationDidFinishLaunching`
- Don't use modern menu APIs - deprecated `popUpMenu` works

### Code
- Don't use `CGEventPostToPid` - doesn't exist in Swift
- Don't use forced unwrapping without nil checks
- Don't overcomplicate with multiple strategy patterns initially

## Configuration

- **Bundle ID**: `com.brndnsvr.WakeyWakey`
- **Deployment Target**: macOS 15.0
- **Architecture**: arm64 only
- **Code Signing**: Automatic (set in project.yml)

## Permissions

Requires Accessibility permission to post CGEvents:
- System Settings → Privacy & Security → Accessibility
- Add WakeyWakey, enable, relaunch

Check with: `AXIsProcessTrusted()`

## Testing Checklist

- [ ] Menu bar icon appears (no Dock icon)
- [ ] Clicking icon shows menu
- [ ] Enable/Disable toggle works
- [ ] Icon changes (cup.and.saucer ↔ cup.and.saucer.fill)
- [ ] Jiggle only happens after 42s idle
- [ ] No jiggle while typing
- [ ] Multi-monitor: cursor stays on current display
- [ ] System doesn't sleep while enabled

## Timings

| Parameter | Value |
|-----------|-------|
| Idle threshold | 42 seconds |
| Jiggle interval | 42-79 seconds (random) |
| Step size | 11-23 pixels (random) |
| Center bias | 52% |
| Heartbeat | 1 Hz |
