# AGENTS.md

## Project Overview

WakeyWakey is a Swift/AppKit macOS menu bar application that keeps the Mac awake. It runs as a menu bar app with no Dock icon (LSUIElement=true), and has two modes:
- **Wakey** — the original behavior: holds a display-sleep power assertion and simulates subtle mouse movements after the user goes idle. Needs Accessibility permission.
- **Lights** ("lights on, nobody home") — holds the power assertions of `caffeinate -disu` with no simulated input. Needs no Accessibility permission; chat apps may show you as Away.

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
./scripts/release.sh 1.5.0

# Create DMG and publish to GitHub
./scripts/release.sh 1.5.0 --publish
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
│   ├── PowerPlan.swift          # Pure mapping: mode + Lights options → assertions, caffeinate string
│   ├── PowerAssertionController.swift  # IOKit wrapper: applies/releases assertions, declares user activity
│   ├── EnabledSession.swift     # Saved enabled session (indefinite / until Date), resume rules, UserDefaults store
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
        button.target = self
        button.action = #selector(statusItemClicked)
    }
    updateStatusIcon()  // Coffee cup, filled while enabled
    statusItem.menu = menu  // Must assign menu
}

@objc func statusItemClicked() {
    statusItem.popUpMenu(menu)  // Deprecated but working
}

// Status icon: the coffee cup in every mode, filled while enabled. It does not
// change with the mode; the mode is shown in the menu. Called from
// updateUIForState() whenever isEnabled changes.
private func updateStatusIcon() {
    guard let button = statusItem.button else { return }
    let symbol = isEnabled ? "cup.and.saucer.fill" : "cup.and.saucer"
    let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "WakeyWakey")
    image?.isTemplate = true  // For dark mode
    button.image = image
}
```

### Power Management

`PowerPlan` (pure mapping, no IOKit) describes what each mode holds while enabled; `PowerAssertionController` (IOKit) creates and releases the assertions it describes. `Settings.powerPlan` computes the current plan from `mode` and the three Lights options.

| | Wakey | Lights |
|---|---|---|
| Held while enabled | `PreventUserIdleDisplaySleep` | `PreventUserIdleSystemSleep` (always) + `PreventUserIdleDisplaySleep` (if `-d`) + `PreventSystemSleep` (if `-s`) |
| Assertion name | `WakeyWakey Active` (unchanged) | `WakeyWakey Lights` |
| One-shot on enable | none | `IOPMAssertionDeclareUserActivity(kIOPMUserActiveLocal)` (if `-u`) |
| Idle detection + jiggle | yes (unchanged) | none; `tick()` returns early |
| Accessibility | required | not needed |
| `caffeinate` equivalent | n/a | `caffeinate -` + `d`? + `i` + `s`? + `u`?; defaults give `-disu` |

`PreventSystemSleep` is used as a raw string, not the SDK's `kIOPMAssertionTypePreventSystemSleep` constant — that constant is deprecated (marked "not supported" since 10.9), even though `caffeinate -s` still creates the assertion and `pmset -g assertions` still reports it.

```swift
// PowerAssertionController.apply(_:): create every assertion in the new plan
// first, then release whichever set was held before. Never a gap in between.
@discardableResult
func apply(_ plan: PowerPlan) -> [String] {
    var newIDs: [IOPMAssertionID] = []
    var newTypes: [String] = []
    var failedTypes: [String] = []

    for type in plan.assertionTypes {
        var assertionID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            plan.assertionName as CFString,
            &assertionID
        )
        if result == kIOReturnSuccess {
            newIDs.append(assertionID)
            newTypes.append(type)
        } else {
            failedTypes.append(type)
        }
    }

    // New set is in place; only now release the old one
    let oldIDs = heldIDs
    heldIDs = newIDs
    heldTypes = newTypes
    oldIDs.forEach { IOPMAssertionRelease($0) }

    return failedTypes
}
```

`AppDelegate.applyPowerPlan(_:)` calls `powerController.apply(plan)` on enable, on a mode switch, and on a Lights checkbox change while enabled — the same create-before-release path every time, so the Mac is never left without an assertion mid-swap.

## Architecture

### Lifecycle
1. `main.swift` → `NSApplication.shared` → `AppDelegate()` → `app.run()`
2. `AppDelegate.init()` sets `.accessory` policy (no Dock icon)
3. `applicationDidFinishLaunching`: status item, menu, accessibility check (Wakey only), 1Hz timer
4. User toggles Enable → `PowerAssertionController` applies `settings.powerPlan`, start/stop scheduling
5. `tick()` runs every second → in Wakey: idle detection → schedule/perform jiggles; in Lights: returns early after the timer-expiry check (no idle detection, no jiggle)

### Idle Detection
```swift
let types: [CGEventType] = [.mouseMoved, .leftMouseDown, .leftMouseDragged,
    .rightMouseDown, .rightMouseDragged, .otherMouseDown, .otherMouseDragged,
    .scrollWheel, .keyDown, .keyUp, .flagsChanged]
let idle = types.map { CGEventSource.secondsSinceLastEventType(.hidSystemState, $0) }.min()!
```
- Takes minimum across explicit event types (handles DisplayLink/virtual display stacks)
- Threshold: 42 seconds
- Wakey only; Lights never runs idle detection or the jiggle

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
No explicit state enum — uses `isEnabled` bool + `nextActivityDueAt` date, plus `settings.mode`:
- **Disabled** (`isEnabled == false`): waiting for user to enable
- **Enabled, Wakey, user active** (idle < threshold OR mouse moved): cancel any animation, clear schedule
- **Enabled, Wakey, just went idle** (`nextActivityDueAt == nil`): jiggle immediately, schedule next
- **Enabled, Wakey, waiting** (`nextActivityDueAt` in future): waiting for next scheduled jiggle
- **Enabled, Lights**: `tick()` returns after the timer-expiry check; only the held power assertions matter
- **Mode switch while enabled**: `PowerAssertionController` applies the new plan (new before old), any Wakey jiggle animation is cancelled, `nextActivityDueAt` and mouse-tracking state are reset, and switching into Lights with `-u` on declares user activity once
- **Timer expired** (`timerExpiresAt` reached): auto-disable, release whichever power assertion set is held

### Saved Session (Stay On After a Restart)
`isEnabled` and `timerExpiresAt` both save the live session (`EnabledSession`: `.indefinite` / `.until(Date)`, or nil while disabled) through `EnabledSessionStore` in their `didSet`, so every path that changes them — menu, timers, Enable Until, CLI, timer expiry — persists without extra calls. Keys: `savedSessionEnabled`, `savedSessionExpiresAt`.
- **Launch**: `resumeSavedSession()` runs after `observeSettingsChanges()`. If `settings.restoreAfterRestart` is on, `EnabledSession.resumable(_:now:)` decides: indefinite resumes, a future end resumes with the same wall-clock end, a past end stays disabled. Anything not resumed is cleared.
- **Quit from the menu** (`quitFromMenu`) clears the saved session before `NSApp.terminate`, so it means "stay off next time". Any other exit — the quit Apple Event sent at logout/restart, SIGTERM (`kill.sh`), a crash — leaves it, and the next launch resumes.
- The relaunch itself comes from Launch at Login; nothing new runs before login. Sleep needs no handling: the process keeps running.

### Settings System
`Settings.swift` is a singleton (`Settings.shared`) backed by `UserDefaults` with `@Published` properties and Combine integration. Settings UI is in `Settings/SettingsWindowController.swift` and `Settings/SettingsViewController.swift`.

`AppDelegate` runs three independent subscriptions, all `receive(on: .main)` because `@Published` fires in `willSet`:
- `Publishers.CombineLatest3` on the three timer durations, to update the menu's timer item titles.
- `Publishers.CombineLatest4` on `mode` and the three Lights options, feeding `powerSettingsChanged()` to keep the *held power assertions* in sync. This sink returns early while disabled, since there is nothing to re-apply.
- A separate `settings.$mode` subscription that drives `updateModeMenuState()` (the menu's Wakey/Lights checkmarks). This one is deliberately kept apart from the CombineLatest4 sink above: it must update the checkmarks on every mode change regardless of enabled state, which the power sink cannot guarantee since it exits early while disabled. Folding it into that sink would leave the checkmarks stale after a mode change made while disabled. The status icon does not depend on the mode, so this subscription does not touch it.

`SettingsViewController` runs its own `Publishers.CombineLatest4` on `mode` and the three Lights options (independent of `AppDelegate`'s), so the open Settings window's segmented control, checkboxes, dim state, and "Equivalent: caffeinate ..." line stay live when the mode or an option changes from the menu or the CLI while the window is open.

Settings, the menu, and the CLI all write the same `Settings` properties, so every surface stays consistent.

Configurable values: `mode` (`KeepAwakeMode`: `.wakey` / `.lights`), the three Lights options (`lightsKeepDisplayOn`, `lightsPreventSystemSleep`, `lightsWakeDisplay`, all default `true`), `restoreAfterRestart` (default `true`), timer durations (3), idle threshold, jiggle interval min/max. `Settings.powerPlan` derives the current `PowerPlan` from `mode` and the Lights options. All have sensible defaults and a `resetToDefaults()` method, which also resets the mode to Wakey and all three Lights options to on. The Accessibility prompt (`requestAccessibilityPermissionIfNeeded`) runs only in Wakey — at launch, and again when switching into Wakey while not yet trusted.

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
- [ ] Icon changes (cup.and.saucer ↔ cup.and.saucer.fill) and stays the cup when switching modes
- [ ] Timer options (default 1h10m/4h20m/9h, configurable) enable and auto-disable
- [ ] Launch at Login toggle works (verify in System Settings → Login Items)
- [ ] Fresh install auto-opens Accessibility settings, in Wakey mode only
- [ ] Jiggle only happens after 42s idle, in Wakey mode
- [ ] No jiggle while typing
- [ ] Multi-monitor: cursor stays on current display
- [ ] System doesn't sleep while enabled, in either mode
- [ ] Wakey enabled: `pmset -g assertions | grep -A1 WakeyWakey` shows one `PreventUserIdleDisplaySleep` named "WakeyWakey Active"
- [ ] Lights enabled (defaults): `pmset -g assertions | grep -A1 WakeyWakey` shows `PreventUserIdleSystemSleep`, `PreventUserIdleDisplaySleep`, and `PreventSystemSleep`, all named "WakeyWakey Lights"
- [ ] Lights enabled: no cursor movement over time, and no Accessibility prompt
- [ ] Switching modes while enabled swaps the assertion set with no gap (new assertions appear before the old ones are released)
- [ ] Settings: the inactive mode's section is dimmed; the "Equivalent: caffeinate ..." line tracks the checked Lights options
- [ ] `wakey mode`, `wakey mode wakey`, `wakey mode lights` work, and `wakey status` reports the mode
- [ ] `wakey enable 2h`, then `./scripts/kill.sh` and relaunch: `wakey status` shows enabled with the same end time
- [ ] Quit event (`osascript -e 'tell application id "com.brndnsvr.WakeyWakey" to quit'`) and relaunch: still enabled
- [ ] Quit from the menu and relaunch: disabled
- [ ] Settings → Startup unchecked: a saved session is ignored at launch

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

Tasks for this repo live in Plane on `plane-goa` (workspace `wzrd`, project
"bss Releases release WakeyWakey" — no Plane project yet; create one on first task). Repo-local markdown task trackers are retired — do not recreate them or mint new local task numbers.

**Workflow:**
- Read and update items in Plane (Plane UI or the `wzrd-plane-bridge` skill)
- Create a Plane item for non-trivial work (>15 min or worth tracking)
- Reference the Plane task ID in commits: `<PLANE-ID>: description`
- Branch naming: `<plane-id>-short-description`
- Legacy local task IDs survive only in historical git history — never assign new ones
