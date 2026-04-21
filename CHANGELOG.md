# Changelog

All notable changes to this project will be documented in this file.

The format is inspired by Keep a Changelog, and this project follows semantic versioning.

## [1.0.6] - 2026-04-21

### Added
- Show actionable temperature hint when reading fails (issue #12)
- Wire SettingsView to the Settings scene (issue #17)

### Changed
- Two-phase ps sampling for space-safe command parsing (issue #29)
- Make ProcessSnapshotProvider a singleton actor to persist metadataCache (issue #28)
- Cache preferred languages and avoid recomputing Locale.preferredLanguages on every L10n call (issue #27)
- Cache available localizations in static let for L10n (issue #25)
- Split system-wide memory pressure from per-process RSS in SystemSummary (issue #13)
- Run NSRunningApplication metadata lookups off main thread with bounded concurrency (issue #9)
- Skip shell fork when temperature tools unavailable (issue #8)

### Fixed
- Remove unguarded exit(0) fallback from quit flow (issue #35)
- Remove redundant onChange handlers — side effects now in ViewModel didSet only (issue #32)
- Fix stale temperature points break sparkline instead of silently reusing last value (issue #31)

## [1.0.1] - 2026-03-30

### Added
- Persisted display preferences across launches for key UI settings.
- Modern macOS login-item integration using `SMAppService`.
- Clearer login-item feedback and status messaging.

### Changed
- Moved summary and process sampling work off the main actor to reduce UI-thread pressure.
- Reduced expensive process metadata lookups with prioritized caching.
- Improved bounded top-process selection and related history handling.
- Simplified Quit behavior for the menu bar app.
- Clarified CPU display semantics to show raw per-process CPU percentages, which may exceed 100% on multicore Macs.

### Fixed
- Lowered the Swift tools version to 6.1 for better CI compatibility.
- Fixed release-note generation so artifact metadata renders correctly in GitHub Releases.

## [1.0.0] - 2026-03-27

### Added
- Initial public MVP release.
- Native macOS menu bar summary for CPU, memory, and thermal state.
- Top apps by CPU and by memory.
- Manual refresh and automatic refresh support.
- Search filtering by app name, path, PID, and bundle identifier.
- Adjustable process row count.
- Best-effort CPU temperature support via helper tools when available.
- Local install/build helper scripts.
- GitHub Actions CI for Swift package and app bundle builds.
- MIT license, release workflow, and project documentation.

[1.0.1]: https://github.com/ShadyUnderLight/ProcessBarMonitor/releases/tag/v1.0.1
[1.0.0]: https://github.com/ShadyUnderLight/ProcessBarMonitor/releases/tag/v1.0.0
