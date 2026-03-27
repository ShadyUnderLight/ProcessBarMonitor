# ProcessBarMonitor

A native macOS menu bar app MVP built with SwiftUI.

## Features
- Menu bar utility with live summary in the menu bar title
- Overall CPU usage
- Memory used / total memory
- Thermal state (Nominal / Fair / Serious / Critical)
- Top 8 processes by CPU
- Top 8 processes by memory
- Manual refresh + automatic refresh every 2 seconds
- Best-effort CPU temperature support placeholder

## Notes on CPU temperature
macOS does not expose CPU temperature through a stable public API for normal apps. This app therefore:
- tries to read temperature from installed helper tools such as `osx-cpu-temp` or `istats`
- falls back to `--` plus thermal state if no helper is available
- does **not** require sudo or private entitlements

## Project structure
- `Sources/ProcessBarMonitor/` — app source
- `ProcessBarMonitor/Info.plist` — optional bundle metadata reference

## Run
Open the folder in Xcode and run the `ProcessBarMonitor` package target, or build with SwiftPM if your local Swift/Xcode toolchain supports SwiftUI app executables.

Typical local commands:

```bash
cd /tmp/process-bar-monitor
swift run
```

If you want a proper `.app` bundle, the easiest route is opening this package in Xcode and using Product → Archive / Run.

## Current limitation on this machine
I could not verify a local build in the current environment because the active Command Line Tools / Swift SDK toolchain is mismatched with the installed Swift compiler, and full Xcode is not currently selected.

Observed issue:
- `xcodebuild` unavailable because active developer directory points to CommandLineTools
- Swift SDK/compiler mismatch prevents a clean compile here

## Included in current MVP
- Top CPU and top memory process lists
- Search box for filtering by process name / path / PID
- Adjustable process count (8 / 12 / 20)
- Manual refresh button
- Quit button in the panel

## Possible next upgrades
- Add sparklines/history
- Add per-process kill button
- Add optional third-party sensor integration for real CPU temperature
- Add launch at login

## Release process
Create a packaged GitHub release with:

```bash
./release.sh 1.0.1 2
```

Arguments:
- first argument: semantic version without or with `v` prefix
- second argument: build number (optional, defaults to `1`)

What it does:
- builds the app bundle
- stamps version/build into `Info.plist`
- zips `dist/ProcessBarMonitor.app`
- creates or updates the Git tag and GitHub Release
- uploads the zipped release asset
