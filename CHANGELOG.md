# Changelog

All notable changes to WakeyWakey will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Weekly schedule in Settings: blocks with days, start and end times in 5-minute steps, and a mode, over a week-at-a-glance strip. WakeyWakey turns on at a block's start and off at its end (only what the schedule turned on), a manual off skips the rest of the block, your own Enable or timers run to their end, and a later start wins where blocks overlap.
- "Schedule:" line in the menu and in `wakey status` showing what the schedule is doing.

### Changed
- The Settings window is wider, in two columns, to make room for the schedule.
- The "Jiggle Behavior" settings section is now "Keepalive Timers".
- Restore Defaults turns the schedule off but keeps its blocks.

## [1.5.0] - 2026-09-28

### Added
- WakeyWakey now stays on across restarts, logouts, crashes, and updates. When it reopens (via Launch at Login), it turns back on with the same end time; a timer that ran out while the Mac was off stays off.
- "Stay on after a restart" setting in a new Startup section of Settings, on by default.

### Changed
- Quit from the menu now also means "stay off next time"; it clears the saved state so the next launch starts disabled.

## [1.4.1] - 2026-09-28

### Changed
- The menu bar icon stays the coffee cup in both modes; Lights mode no longer switches it to a lightbulb. The mode is shown in the menu.

## [1.4.0] - 2026-09-28

### Added
- Lights mode: holds the power assertions of `caffeinate -disu` with no simulated input, for when you want to look present without moving the cursor.
- Three Lights options — keep the display on (`-d`), prevent system sleep on AC power (`-s`), wake the display when enabled (`-u`) — all on by default; `-i` is always held.
- "Mode" section in the menu, with Wakey and Lights items and a checkmark on the active mode.
- Lightbulb menu bar icon (`lightbulb` / `lightbulb.fill`) for Lights mode, alongside the existing coffee cup for Wakey.
- `wakey mode` CLI command to show or set the mode (`wakey mode wakey` / `wakey mode lights`).

### Changed
- Settings window layout: a new "Mode" section at the top, a new "Lights Behavior" section with the three checkboxes and a live "Equivalent: caffeinate -disu" line, and both mode sections now full width; the section for the inactive mode is dimmed.
- The Accessibility permission prompt now appears only in Wakey mode; Lights mode never prompts for it.

## [1.3.1] - 2026-08-11

### Added
- Menu bar field for enabling WakeyWakey until a specific 12-hour clock time.
- Clock-time parsing for values such as `5pm`, `5:00`, and `5:30pm`; times without AM/PM use the next 12-hour occurrence.
- Decimal-hour CLI durations such as `wakey enable 3.5h`.

### Changed
- Defaults now use 1h10m, 4h20m, and 9h timer presets.
- Default jiggle repeat interval now starts at 12 seconds and ends at 79 seconds.

### Fixed
- Settings number fields now place the caret for inline editing and preserve valid min/max ranges.

## [1.1.0] - 2025-01-13

### Added
- Settings panel with customizable timer durations, idle threshold, and jiggle intervals
- Animated multi-step jiggle with varied paths (arc, zigzag, direct) and timing patterns
- Power assertion failure warning in menu when system prevents sleep control
- Universal Control detection to avoid jiggles during cross-device use

### Changed
- Release builds now default for /Applications installation (consistent code signing)
- Settings validation moved to single source of truth (Settings.swift)

### Fixed
- Memory leak when opening/closing Settings window repeatedly
- Potential crash when displays hot-unplugged during jiggle
- Animation race condition when user becomes active mid-jiggle
- Inconsistent min/max interval validation in Settings UI

## [1.0.2] - 2024-12-31

### Fixed
- Screensaver now properly prevented when enabled (was only preventing system sleep, not display sleep)

## [1.0.1] - 2024-12-31

### Changed
- App is now notarized for Gatekeeper compliance — no more security warnings on first launch

## [1.0.0] - 2024-12-30

### Added
- Menu bar app with Enable/Disable toggle
- Timer options: enable for 1, 4, or 8 hours with auto-disable
- Launch at Login toggle (via SMAppService)
- Automatic Accessibility permission prompt
- Smart idle detection (42s threshold)
- Random mouse jiggle at 42-79s intervals
- Multi-monitor support with cursor clamping
- Center bias (52%) to prevent edge drift

[1.5.0]: https://github.com/brndnsvr/WakeyWakey/releases/tag/v1.5.0
[1.4.1]: https://github.com/brndnsvr/WakeyWakey/releases/tag/v1.4.1
[1.4.0]: https://github.com/brndnsvr/WakeyWakey/releases/tag/v1.4.0
[1.3.1]: https://github.com/brndnsvr/WakeyWakey/releases/tag/v1.3.1
[1.1.0]: https://github.com/brndnsvr/WakeyWakey/releases/tag/v1.1.0
[1.0.2]: https://github.com/brndnsvr/WakeyWakey/releases/tag/v1.0.2
[1.0.1]: https://github.com/brndnsvr/WakeyWakey/releases/tag/v1.0.1
[1.0.0]: https://github.com/brndnsvr/WakeyWakey/releases/tag/v1.0.0
