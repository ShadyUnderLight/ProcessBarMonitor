# Changelog

All notable changes to this project will be documented in this file.

The format is inspired by Keep a Changelog, and this project follows semantic versioning.

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
