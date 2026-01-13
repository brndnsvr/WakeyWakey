# Changelog

All notable changes to WakeyWakey will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.1.0]: https://github.com/brndnsvr/WakeyWakey/releases/tag/v1.1.0
[1.0.2]: https://github.com/brndnsvr/WakeyWakey/releases/tag/v1.0.2
[1.0.1]: https://github.com/brndnsvr/WakeyWakey/releases/tag/v1.0.1
[1.0.0]: https://github.com/brndnsvr/WakeyWakey/releases/tag/v1.0.0
