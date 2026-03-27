# ProcessBarMonitor

A native macOS menu bar app for watching CPU, memory, thermal state, and top processes at a glance.

## What it does
- Shows a compact live summary in the macOS menu bar
- Displays overall CPU usage, memory usage, and thermal state
- Lists top apps by CPU and by memory
- Supports manual refresh, search, and adjustable row count
- Includes launch-at-login support

## Current status
This is an early but usable MVP.

## Features
- Menu bar utility with live summary in the menu bar title
- Overall CPU usage
- Memory used / total memory
- Thermal state (Nominal / Fair / Serious / Critical)
- Top apps by CPU
- Top apps by memory
- Manual refresh + automatic refresh
- Best-effort CPU temperature support
- Search box for filtering by app name / path / PID / bundle id
- Adjustable process row count
- Quit button in the panel

## Installation
### Download a packaged app
Download the latest release from GitHub Releases and unzip `ProcessBarMonitor.app`.

### Install locally from this repo
```bash
./install_app.sh
```

## Development
Open the project in Xcode and run it there, or use the included helper scripts.

Build an app bundle locally:

```bash
./build_app.sh
```

## CI
GitHub Actions now builds the Swift package and app bundle automatically on pushes, pull requests, and version tags.

## Notes on CPU temperature
macOS does not expose CPU temperature through a stable public API for normal apps. This app therefore:
- tries to read temperature from installed helper tools such as `osx-cpu-temp` or `istats`
- falls back to `--` plus thermal state if no helper is available
- does **not** require sudo or private entitlements

## Known limitations
- CPU temperature is best-effort rather than guaranteed
- Process sampling can still be relatively expensive on some systems
- The app is still being polished for wider public release

## Roadmap ideas
- Sparklines / history
- Per-process actions
- Better sensor integrations
- Further performance tuning

## Maintainer notes
Release workflow is documented in `RELEASING.md`.
