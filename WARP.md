# WARP.md

WakeyWakey • Warp Terminal Quickstart and Workflows

Use this file as a Warp-friendly reference for common tasks in this repo.

Prerequisites
- macOS 15.0+
- Xcode + macOS 15 SDK
- Homebrew (for XcodeGen)
- Accessibility permissions for WakeyWakey (required to post CGEvents)

Project bootstrap
```bash path=null start=null
# One-time
brew install xcodegen

# Generate Xcode project
./scripts/generate_project.sh

# (Optional) Regenerate AppIcon from PNG if you change it
./scripts/generate_appicon.sh
```

Build and run
- Debug
```bash path=null start=null
./scripts/build_debug.sh
./scripts/install.sh
./scripts/run.sh
```
- Release
```bash path=null start=null
./scripts/build_release.sh
cp -R build/Build/Products/Release/WakeyWakey.app /Applications/
```
- Kill the app
```bash path=null start=null
./scripts/kill.sh
```

Git quick actions
```bash path=null start=null
# Status
git status --porcelain -uno

# Commit and push current branch
git add -A
git commit -m "chore: update"
git push -u origin $(git branch --show-current)
```

Warp Drive workflows (available examples)
- Delete local and remote git branch
```bash path=null start=null
git push -d {{remote_name}} {{branch_name}}
git branch -d {{branch_name}}
```
- Delete remote git branch
```bash path=null start=null
git push -d {{remote_name}} {{branch_name}}
```

Notes specific to WakeyWakey
- Menu bar app only (no Dock icon); LSUIElement=true
- Idle detection considers explicit keyboard and mouse events to avoid jiggles while typing
- 52% of jiggles bias toward the center of the current screen; 48% random small moves
- Multi-monitor safe: movement is clamped to the screen under the cursor and coordinates are anchored to the main display to avoid snapping (DisplayLink compatible)

Troubleshooting
- If the app can’t control the mouse, grant Accessibility permission:
  System Settings > Privacy & Security > Accessibility > add WakeyWakey and enable it, then relaunch
- If first launch is blocked: Control-click the app in /Applications and choose Open
