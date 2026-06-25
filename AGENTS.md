# AGENTS.md

## Project Overview

WakeyWakey is a Swift/AppKit macOS menu bar application that prevents system idle sleep by simulating subtle mouse movements. It runs as a menu bar app with no Dock icon (LSUIElement=true).

**Tech Stack**: Swift, AppKit, IOKit, ServiceManagement, XcodeGen
**Target**: macOS 15.0+, arm64

## Quick Commands

```bash
# One-time setup
brew install xcodegen
./scripts/generate_project.sh

# Build, install, and run (Release - recommended)
./scripts/build.sh
./scripts/install.sh
./scripts/run.sh

# Quick iteration (Debug - development only)
./scripts/build_debug.sh
./scripts/install.sh
./scripts/run.sh

# Kill the app
./scripts/kill.sh

# Create DMG for distribution
./scripts/release.sh 1.2.2

# Create DMG and publish to GitHub
./scripts/release.sh 1.2.2 --publish
```

**Note**: Always use `build.sh` (Release) when installing to /Applications. Debug builds use a different signing identity which causes Accessibility permission re-prompts on upgrade.

## Git Workflow

**Always branch from main for any changes:**

1. Create a branch with descriptive name:
   ```bash
   git checkout -b <type>/<short-description>
   ```

   | Type | Use for |
   |------|---------|
   | `feat/` | New features |
   | `fix/` | Bug fixes |
   | `docs/` | Documentation |
   | `refactor/` | Code restructuring |
   | `chore/` | Maintenance |

2. Make changes and commit

3. Push and create PR:
   ```bash
   git push -u origin <branch-name>
   gh pr create --fill
   ```

4. Merge PR to main (squash or merge commit)

**Never commit directly to main.**

## Project Structure

```
repo root
├── WakeyWakey/
│   ├── main.swift               # Required entry point for menu bar apps
│   ├── AppDelegate.swift        # Menu, timers, jiggle animation, power management
│   ├── CLIServer.swift          # CFMessagePort IPC server for the wakey CLI
│   ├── Settings.swift           # UserDefaults-backed settings with Combine publishers
│   ├── Settings/
│   │   ├── SettingsWindowController.swift
│   │   └── SettingsViewController.swift
│   ├── Assets.xcassets          # App icon
│   └── Resources/Info.plist     # LSUIElement=true
├── wakey/
│   └── main.swift               # CLI client target
├── scripts/                     # Build automation
├── project.yml                  # XcodeGen configuration
└── README.md                    # User documentation
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
// Prevent idle sleep AND display sleep (NoIdleSleep only prevents system sleep, not screensaver)
IOPMAssertionCreateWithName(
    kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
    IOPMAssertionLevel(kIOPMAssertionLevelOn),
    "WakeyWakey Active" as CFString,
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

### Idle Detection
```swift
let types: [CGEventType] = [.mouseMoved, .leftMouseDown, .leftMouseDragged,
    .rightMouseDown, .rightMouseDragged, .otherMouseDown, .otherMouseDragged,
    .scrollWheel, .keyDown, .keyUp, .flagsChanged]
let idle = types.map { CGEventSource.secondsSinceLastEventType(.hidSystemState, $0) }.min()!
```
- Takes minimum across explicit event types (handles DisplayLink/virtual display stacks)
- Threshold: 42 seconds

### Jiggle Animation
Animated multi-waypoint movement (not instant teleport):
- **Path types**: Arc (40%), zigzag (35%), direct (25%) — selected randomly
- **Waypoints**: 4-8 steps per jiggle
- **Total distance**: 15-35 pixels per jiggle
- **Duration**: 0.5-1.0 seconds per animation
- **Timing patterns**: accelerate-decelerate (50%), steady (30%), quick-pause-quick (20%)
- **Center bias**: 52% of jiggles move toward screen center
- **Max deviation**: 22 degrees from direct path
- **Clamping**: Constrain to current screen bounds
- **Fallback**: Simple 11-23px instant move if Quartz coords unavailable

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

### State Logic
No explicit state enum — uses `isEnabled` bool + `nextActivityDueAt` date:
- **Disabled** (`isEnabled == false`): waiting for user to enable
- **Enabled, user active** (idle < threshold OR mouse moved): cancel any animation, clear schedule
- **Enabled, just went idle** (`nextActivityDueAt == nil`): jiggle immediately, schedule next
- **Enabled, waiting** (`nextActivityDueAt` in future): waiting for next scheduled jiggle
- **Timer expired** (`timerExpiresAt` reached): auto-disable, release power assertion

### Settings System
`Settings.swift` is a singleton (`Settings.shared`) backed by `UserDefaults` with `@Published` properties and Combine integration. `AppDelegate` subscribes to changes via `Publishers.CombineLatest3` to update menu titles dynamically. Settings UI is in `Settings/SettingsWindowController.swift` and `Settings/SettingsViewController.swift`.

Configurable values: timer durations (3), idle threshold, jiggle interval min/max. All have sensible defaults and a `resetToDefaults()` method.

### Universal Control Detection
Tracks mouse position changes between ticks to detect cursor movement from Universal Control (which doesn't register as HID events). If the cursor moved since last check, the user is considered active even if `CGEventSource.secondsSinceLastEventType` shows high idle time.

### Timer Feature
```swift
private var timerExpiresAt: Date?  // nil = no timer, Date = auto-disable time

private func enableForDuration(_ seconds: TimeInterval) {
    timerExpiresAt = Date().addingTimeInterval(seconds)
    if !isEnabled {
        isEnabled = true
        beginPreventingSleep()
    }
}

// In tick(): check expiration before other logic
if let expiresAt = timerExpiresAt, Date() >= expiresAt {
    timerExpiresAt = nil
    isEnabled = false
    endPreventingSleep()
    return
}
```

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
- **CLI Bundle ID**: `com.brndnsvr.WakeyWakey.cli`
- **Deployment Target**: macOS 15.0
- **Architecture**: arm64 only
- **Code Signing**: Automatic (set in project.yml)

## Permissions

### Accessibility
Requires Accessibility permission to post CGEvents. On first launch, the app automatically opens System Settings using `AXIsProcessTrustedWithOptions(kAXTrustedCheckOptionPrompt: true)`.

```swift
private func requestAccessibilityPermissionIfNeeded() {
    if !AXIsProcessTrusted() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
```

### Launch at Login
Uses SMAppService (macOS 13+) for login item management:

```swift
import ServiceManagement

// Check status
SMAppService.mainApp.status == .enabled

// Toggle
try SMAppService.mainApp.register()   // Enable
try SMAppService.mainApp.unregister() // Disable
```

State is managed by the system and visible in System Settings → General → Login Items.

## Testing Checklist

- [ ] Menu bar icon appears (no Dock icon)
- [ ] Clicking icon shows menu
- [ ] Enable/Disable toggle works
- [ ] Icon changes (cup.and.saucer ↔ cup.and.saucer.fill)
- [ ] Timer options (default 1h10m/4h20m/9h, configurable) enable and auto-disable
- [ ] Launch at Login toggle works (verify in System Settings → Login Items)
- [ ] Fresh install auto-opens Accessibility settings
- [ ] Jiggle only happens after 42s idle
- [ ] No jiggle while typing
- [ ] Multi-monitor: cursor stays on current display
- [ ] System doesn't sleep while enabled

## Timings (Defaults — configurable via Settings)

| Parameter | Default | Configurable |
|-----------|---------|--------------|
| Idle threshold | 42 seconds | Yes |
| Jiggle interval | 12-79 seconds (random) | Yes (min/max) |
| Total distance | 15-35 pixels (random) | No |
| Center bias | 52% | No |
| Heartbeat | 1 Hz | No |
| Timer presets | 1h10m / 4h20m / 9h | Yes |

## Task Tracking

This project uses centralized task tracking via [ctrl](https://github.com/brndnsvr/ctrl).

- **Task file:** `.task-tracking/TASKS.md` (symlink to `~/ctrl/.task-tracking/repos/bss/_Apps/WakeyWakey/`)
- **ID format:** `WW-XXX` (e.g., `WW-001`)
- **Never renumber** existing IDs
- If `.task-tracking/TASKS.md` is absent in a release checkout, note that and proceed without inventing task IDs unless asked to wire up ctrl.

### Workflow
- Check Inflight section before starting work when the task file exists
- Create tasks for non-trivial work (>15 min or worth tracking) when the task file exists
- Move tasks between sections: Inbox -> Next -> Inflight -> Done
- Reference task IDs in commits when available: `WW-XXX: description`
- Branch naming with task ID: `ww-XXX-short-description`; otherwise use `<type>/<short-description>`

### Labels
bug, feature, refactor, docs, infra, automation
