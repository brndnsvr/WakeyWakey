# WakeyWakey

A tiny macOS menu bar app that keeps your Mac awake — jiggle the cursor after you go idle (Wakey), or just hold the power assertions with no simulated input (Lights).

**Website:** [wakeywakey.app](https://wakeywakey.app)

## Install

### Homebrew (recommended)

```bash
brew install --cask brndnsvr/tap/wakeywakey
```

This installs both the menu bar app and the `wakey` CLI.

### Manual Download

**[Download WakeyWakey v1.4.1](https://github.com/brndnsvr/WakeyWakey/releases/download/v1.4.1/WakeyWakey-1.4.1.dmg)** (macOS 15.0+, Apple Silicon)

Or visit [Releases](https://github.com/brndnsvr/WakeyWakey/releases) for all versions.

1. Download the DMG above
2. Open it and drag WakeyWakey to Applications

## Getting Started

1. Launch WakeyWakey from Applications
2. In Wakey mode, grant Accessibility permission when prompted (required for the simulated mouse movement); Lights mode needs no Accessibility permission
3. Click the menu bar icon to enable

## Features

- **Menu bar only** — no Dock icon, stays out of your way
- **Modes** — Wakey jiggles the cursor after you go idle; Lights holds the same power assertions as `caffeinate -disu` with no simulated input
- **Smart activation (Wakey)** — only jiggles after idle threshold (default 42 seconds)
- **Natural movement (Wakey)** — animated multi-waypoint paths that look like real mouse movement
- **Timer options** — use configurable 1h10m/4h20m/9h presets or enter a clock time such as `5pm` or `5:00`
- **CLI control** — `wakey enable`, `wakey disable`, `wakey status`, `wakey mode` from the terminal
- **Configurable** — adjust mode, timers, idle threshold, and jiggle intervals in Settings
- **Launch at Login** — start automatically with your Mac
- **Stays on after a restart** — if it was on when the Mac restarted, logged out, or updated, it turns back on with the same end time (reopens on its own with Launch at Login)
- **Multi-monitor support** — cursor stays on the current display

## Menu Bar Usage

Click the menu bar icon (coffee cup) to access:

| Menu Item | Action |
|-----------|--------|
| Enable/Disable | Toggle the active mode on/off |
| Mode: Wakey | Switch to Wakey (cursor jiggle) |
| Mode: Lights | Switch to Lights (no simulated input) |
| Enable for 1h10m/4h20m/9h | Auto-disable after set time (configurable) |
| Enable until | Enter a clock time such as `5pm`, `5:00`, or `5:30pm`, then press Return |
| Launch at Login | Start with macOS |
| Settings... | Configure mode, timers, idle threshold, jiggle intervals |
| Quit | Exit the app; it starts off next time |

**Icon states:**

The coffee cup icon is the same in both modes and fills in solid when enabled.

| Disabled | Enabled |
|:--------:|:-------:|
| ![Disabled](docs/assets/icon-disabled.png) | ![Enabled](docs/assets/icon-enabled.png) |

## CLI Usage

The `wakey` command controls WakeyWakey from the terminal (requires the app to be running).

```bash
wakey enable          # Enable indefinitely
wakey enable 2h       # Enable for 2 hours
wakey enable 90m      # Enable for 90 minutes
wakey enable 3.5h     # Enable for 3.5 hours
wakey disable         # Disable
wakey status          # Show current status (includes the active mode)
wakey mode            # Show the current mode
wakey mode wakey      # Switch to Wakey (applies live if enabled)
wakey mode lights     # Switch to Lights (applies live if enabled)
wakey --help          # Show help
```

`wakey status` reports the mode on its own line, such as `Mode: lights (caffeinate -disu)` or `Mode: wakey`.

Installed automatically via Homebrew, or manually:

```bash
# The CLI binary is embedded in the app bundle
cp /Applications/WakeyWakey.app/Contents/MacOS/wakey /usr/local/bin/wakey
```

## Restarts

With **Stay on after a restart** checked (Settings → Startup, on by default) and **Launch at Login** on, WakeyWakey picks up where it left off whenever it reopens — after a restart, logout, crash, or update:

- Enabled with no timer → comes back enabled with no timer
- Enabled until a time → comes back enabled until that same time; if the time passed while the Mac was off, it stays off
- Disabled, or closed with **Quit** from its menu → comes back off

It can only run after you log in. On a Mac with FileVault, that means after someone enters the password following a restart.

Sleep needs none of this: WakeyWakey keeps running while the Mac sleeps, so its state and timer carry on when it wakes.

## Permissions

**Wakey mode** needs **Accessibility permission** to simulate mouse movement. On first launch, or when switching to Wakey, it will open System Settings for you. Grant permission and relaunch.

**Lights mode** needs no Accessibility access — it holds power assertions only and posts no simulated input. Chat apps may show you as Away while Lights is enabled.

If Wakey doesn't work:
1. Go to System Settings → Privacy & Security → Accessibility
2. Find WakeyWakey and toggle it on
3. Relaunch the app

## Troubleshooting

- **App doesn't jiggle** — In Wakey mode, wait 42+ seconds without touching mouse/keyboard. In Lights mode this is expected: Lights never moves the cursor by design; check `pmset -g assertions` for "WakeyWakey Lights" instead.
- **No menu bar icon** — Make sure you're running from /Applications
- **CLI says "not running"** — Launch the WakeyWakey app first

## Development

Want to build from source? See [DEVELOPMENT.md](DEVELOPMENT.md).

## License

[MIT](LICENSE)
