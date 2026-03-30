## ProcessBarMonitor v1.0.2

### Fixed
- Fixed a Top Apps collection failure path where process sampling was launched through `zsh -lc`, which could cause the Top Apps list to appear blank with no explanation.
- Fixed silent failure behavior during process snapshot collection by surfacing user-visible error messages when sampling fails.

### Changed
- Process sampling now invokes `/bin/ps` directly with explicit arguments instead of shelling out through `zsh`.
- Process snapshot errors are now classified more explicitly to distinguish launch failures, non-zero command exits, invalid output decoding, and parsing failures.

### User impact
- Top Apps should now render more reliably in normal operation.
- If sampling fails, the app now shows a clear status message such as `Failed to load top apps: ...` instead of silently showing an empty list.

### Artifact
- `ProcessBarMonitor-v1.0.2-macOS.zip`
- SHA-256: `d4a8d2d5dbec76545df7789dd481f9e1086542dc44ea9280e2ce5a9d989c9c93`

### Notes
- CPU percentages are shown as raw per-process CPU usage and may exceed 100% on multicore Macs.
- CPU temperature is best-effort and may fall back to thermal state when no supported helper tool is available.
- This release ships as a macOS `.app` zipped artifact.
