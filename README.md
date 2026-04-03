# WakeyWakey

A tiny macOS menu bar app that keeps your Mac awake by simulating subtle mouse movements only when you're idle.

**Website:** [wakeywakey.app](https://wakeywakey.app)

## Install

### Homebrew (recommended)

```bash
brew install --cask brndnsvr/tap/wakeywakey
```

This installs both the menu bar app and the `wakey` CLI.

### Manual Download

**[Download WakeyWakey v1.2.0](https://github.com/brndnsvr/WakeyWakey/releases/download/v1.2.0/WakeyWakey-1.2.0.dmg)** (macOS 15.0+, Apple Silicon)

Or visit [Releases](https://github.com/brndnsvr/WakeyWakey/releases) for all versions.

1. Download the DMG above
2. Open it and drag WakeyWakey to Applications

## Getting Started

1. Launch WakeyWakey from Applications
2. Grant Accessibility permission when prompted (required for mouse movement)
3. Click the coffee cup icon in your menu bar to enable

## Features

- **Menu bar only** — no Dock icon, stays out of your way
- **Smart activation** — only jiggles after idle threshold (default 42 seconds)
- **Natural movement** — animated multi-waypoint paths that look like real mouse movement
- **Timer options** — enable for 1h, 4h, or 9h (configurable) with auto-disable
- **CLI control** — `wakey enable`, `wakey disable`, `wakey status` from the terminal
- **Configurable** — adjust timers, idle threshold, and jiggle intervals in Settings
- **Launch at Login** — start automatically with your Mac
- **Multi-monitor support** — cursor stays on the current display

## Menu Bar Usage

Click the menu bar icon (coffee cup) to access:

| Menu Item | Action |
|-----------|--------|
| Enable/Disable | Toggle mouse jiggle on/off |
| Enable for 1h/4h/9h | Auto-disable after set time (configurable) |
| Launch at Login | Start with macOS |
| Settings... | Configure timers, idle threshold, jiggle intervals |
| Quit | Exit the app |

**Icon states:**
- Empty cup (`cup.and.saucer`) — disabled
- Filled cup (`cup.and.saucer.fill`) — enabled

## CLI Usage

The `wakey` command controls WakeyWakey from the terminal (requires the app to be running).

```bash
wakey enable          # Enable indefinitely
wakey enable 2h       # Enable for 2 hours
wakey enable 90m      # Enable for 90 minutes
wakey disable         # Disable
wakey status          # Show current status
wakey --help          # Show help
```

Installed automatically via Homebrew, or manually:

```bash
# The CLI binary is embedded in the app bundle
cp /Applications/WakeyWakey.app/Contents/MacOS/wakey /usr/local/bin/wakey
```

## Permissions

WakeyWakey needs **Accessibility permission** to simulate mouse movement. On first launch, it will open System Settings for you. Grant permission and relaunch.

If it doesn't work:
1. Go to System Settings → Privacy & Security → Accessibility
2. Find WakeyWakey and toggle it on
3. Relaunch the app

## Troubleshooting

- **App doesn't jiggle** — Wait 42+ seconds without touching mouse/keyboard
- **No menu bar icon** — Make sure you're running from /Applications
- **CLI says "not running"** — Launch the WakeyWakey app first

## Development

Want to build from source? See [DEVELOPMENT.md](DEVELOPMENT.md).

## License

[MIT](LICENSE)
