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

**[Download WakeyWakey v1.6.0](https://github.com/brndnsvr/WakeyWakey/releases/download/v1.6.0/WakeyWakey-1.6.0.dmg)** (macOS 15.0+, Apple Silicon)

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
- **Weekly schedule** — turn on by itself in blocks you set, such as weekdays 8–5 in Wakey then 5–8 in Lights, in 5-minute steps
- **Configurable** — adjust mode, timers, idle threshold, jiggle intervals, and the schedule in Settings
- **Launch at Login** — start automatically with your Mac
- **Stays on after a restart** — if it was on when the Mac restarted, logged out, or updated, it turns back on with the same end time (reopens on its own with Launch at Login)
- **Multi-monitor support** — cursor stays on the current display

## Menu Bar Usage

Click the menu bar icon (coffee cup) to access:

| Menu Item | Action |
|-----------|--------|
| Enable/Disable | Toggle the active mode on/off |
| Schedule: … | What the schedule is doing, such as `Schedule: Wakey until 5:00 PM` (shown while a schedule is on) |
| Mode: Wakey | Switch to Wakey (cursor jiggle) |
| Mode: Lights | Switch to Lights (no simulated input) |
| Enable for 1h10m/4h20m/9h | Auto-disable after set time (configurable) |
| Enable until | Enter a clock time such as `5pm`, `5:00`, or `5:30pm`, then press Return |
| Launch at Login | Start with macOS |
| Settings... | Configure mode, timers, idle threshold, jiggle intervals, schedule |
| Quit | Exit the app; it starts off next time, unless a scheduled block is running |

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

`wakey status` reports the mode on its own line, such as `Mode: lights (caffeinate -disu)` or `Mode: wakey`, and the schedule on another, such as `Schedule: next Lights today at 5:00 PM` or `Schedule: off`.

Installed automatically via Homebrew, or manually:

```bash
# The CLI binary is embedded in the app bundle
cp /Applications/WakeyWakey.app/Contents/MacOS/wakey /usr/local/bin/wakey
```

## Schedule

Settings → Schedule turns WakeyWakey on and off by itself. Check **Follow a weekly schedule**, then add blocks: the days, a start and end time (in 5-minute steps), and a mode. For example, weekdays 8:00 AM–5:00 PM in Wakey, then 5:00–8:00 PM in Lights.

- At a block's start WakeyWakey turns on in that block's mode. At its end it turns off, but only if the schedule turned it on; if you had already turned it on yourself, it stays on.
- Turning it off during a block skips the rest of that block. It stays off until the next block starts.
- Your own Enable, timers, and **Enable until** run to their end, then the schedule picks up wherever it is.
- Where blocks overlap, the one that starts later wins, so a short block inside a long one (a Lights lunch hour inside a Wakey workday) takes over for its length.
- An end time before the start runs past midnight.
- Once no block is running, the mode goes back to the one you had picked, unless you picked another since.

The schedule can't wake a sleeping Mac. If the Mac is asleep when a block starts, WakeyWakey turns on when it wakes.

## Restarts

With **Stay on after a restart** checked (Settings → Startup, on by default) and **Launch at Login** on, WakeyWakey picks up where it left off whenever it reopens — after a restart, logout, crash, or update:

- Enabled with no timer → comes back enabled with no timer
- Enabled until a time → comes back enabled until that same time; if the time passed while the Mac was off, it stays off
- Disabled, or closed with **Quit** from its menu → comes back off
- A schedule turns WakeyWakey back on if one of its blocks is running when it reopens

It can only run after you log in. On a Mac with FileVault, that means after someone enters the password following a restart.

Sleep needs none of this: WakeyWakey keeps running while the Mac sleeps, so its state and timer carry on when it wakes.

## Permissions

**Wakey mode** needs **Accessibility permission** to simulate mouse movement. Whenever Wakey is in use without it (first launch, a switch to Wakey, or a scheduled Wakey block), macOS asks, and WakeyWakey keeps its own window on screen until you grant the permission or choose **Use Lights Instead**. The window closes by itself once the permission is granted, and the menu shows a warning line until then.

**Lights mode** needs no Accessibility access — it holds power assertions only and posts no simulated input. Chat apps may show you as Away while Lights is enabled.

If Wakey doesn't move the cursor:
1. Go to System Settings → Privacy & Security → Accessibility
2. Find WakeyWakey and toggle it on. If it isn't listed, click **+** and choose it from Applications
3. If it's already on but WakeyWakey still asks, click **Reset and ask again** in its window, then turn it on again. (The list can stay "on" for an older copy of the app.)
4. If the cursor still doesn't move after a minute idle, quit and reopen WakeyWakey

## Troubleshooting

- **App doesn't jiggle** — In Wakey mode, wait 42+ seconds without touching mouse/keyboard. In Lights mode this is expected: Lights never moves the cursor by design; check `pmset -g assertions` for "WakeyWakey Lights" instead.
- **No menu bar icon** — Make sure you're running from /Applications
- **CLI says "not running"** — Launch the WakeyWakey app first

## Development

Want to build from source? See [DEVELOPMENT.md](DEVELOPMENT.md).

## License

[MIT](LICENSE)
