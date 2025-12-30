# WakeyWakey

A tiny macOS menu bar app that keeps your Mac awake by simulating subtle mouse movements only when you're idle.

## Download

**[Download WakeyWakey v1.0.0](https://github.com/brndnsvr/WakeyWakey/releases/download/v1.0.0/WakeyWakey-1.0.0.dmg)** (macOS 15.0+, Apple Silicon)

Or visit [Releases](https://github.com/brndnsvr/WakeyWakey/releases) for all versions.

## Installation

1. Download the DMG above
2. Open it and drag WakeyWakey to Applications
3. Launch WakeyWakey from Applications
4. Grant Accessibility permission when prompted (required for mouse movement)
5. Click the coffee cup icon in your menu bar to enable

> **Note:** First launch may show a Gatekeeper warning. Control-click the app and choose "Open" to bypass.

## Features

- **Menu bar only** — no Dock icon, stays out of your way
- **Smart activation** — only jiggles after 42 seconds of inactivity
- **Timer options** — enable for 1, 4, or 8 hours with auto-disable
- **Launch at Login** — start automatically with your Mac
- **Multi-monitor support** — cursor stays on the current display

## Usage

Click the menu bar icon (coffee cup) to access:

| Menu Item | Action |
|-----------|--------|
| Enable/Disable | Toggle mouse jiggle on/off |
| Enable for 1/4/8 hours | Auto-disable after set time |
| Launch at Login | Start with macOS |
| Quit | Exit the app |

**Icon states:**

| Disabled | Enabled |
|:--------:|:-------:|
| ![Disabled](docs/assets/icon-disabled.png) | ![Enabled](docs/assets/icon-enabled.png) |

## Permissions

WakeyWakey needs **Accessibility permission** to simulate mouse movement. On first launch, it will open System Settings for you. Grant permission and relaunch.

If it doesn't work:
1. Go to System Settings → Privacy & Security → Accessibility
2. Find WakeyWakey and toggle it on
3. Relaunch the app

## Troubleshooting

- **App doesn't jiggle** — Wait 45+ seconds without touching mouse/keyboard
- **Gatekeeper warning** — Control-click → Open
- **No menu bar icon** — Make sure you're running from /Applications

## Development

Want to build from source? See [DEVELOPMENT.md](DEVELOPMENT.md).

## License

[MIT](LICENSE)
