# ProcessBarMonitor

[中文说明 / 中文 README](README.zh-CN.md)

A native macOS menu bar monitor for CPU, memory, thermal state, and top apps.

## Download
- [Latest release](https://github.com/ShadyUnderLight/ProcessBarMonitor/releases/latest)

## Why this app
ProcessBarMonitor gives you a compact Activity Monitor-style summary without keeping a full window open. It lives in the macOS menu bar and focuses on the system signals you usually want at a glance: CPU load, memory pressure, thermal state, and which apps are currently eating resources.

## Highlights
- Live menu bar summary for CPU, memory, and thermal state
- Top apps by CPU and memory in one click
- Search and adjustable process row count
- Launch at login support
- Best-effort CPU temperature integration when helper tools are available
- Native Swift / SwiftUI macOS app

## Good fit for
- keeping an eye on system load while working
- quickly spotting which app just spiked CPU or memory
- checking thermal state on laptops without opening Activity Monitor
- lightweight menu bar monitoring on Apple silicon Macs

## Features
- Menu bar utility with live summary in the menu bar title
- Overall CPU usage
- Memory pressure (system-wide active + inactive + wired + compressor)
- Thermal state (Nominal / Fair / Serious / Critical)
- Top apps by CPU
- Top apps by memory
- Manual refresh + automatic refresh
- Best-effort CPU temperature support
- Search box for filtering by app name / path / PID / bundle id
- Adjustable process row count
- Persisted display preferences for menu bar mode, temperature mode, and row count
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
