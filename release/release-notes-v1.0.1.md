## ProcessBarMonitor v1.0.1

Packaged macOS release of ProcessBarMonitor.

### Included
- Performance improvements by moving sampling work off the main actor
- Persisted display settings
- Modernized launch at login with `SMAppService`
- Improved login-item feedback and status messaging
- Simplified Quit behavior for the menu bar app
- Refined history handling and optimized bounded top-process selection

### Artifact
- ProcessBarMonitor-v1.0.1-macOS.zip
- SHA-256: `c456e5c09f5bca3db1e6872b08c493215d7d6742c828463e2806786ab12a2cf9`

### Notes
- CPU percentages are shown as raw per-process CPU usage and may exceed 100% on multicore Macs.
- CPU temperature is best-effort and may fall back to thermal state when no supported helper tool is available.
- This release ships as a macOS `.app` zipped artifact.
