## ProcessBarMonitor v1.0.2

Packaged macOS release of ProcessBarMonitor.

### Included
- Fixed Top Apps collection by invoking \/bin\/ps directly instead of routing through `zsh -lc`
- Added explicit Top Apps error messaging so snapshot failures no longer appear as a silent blank list
- Distinguished command launch, non-zero exit, encoding, and parsing failures to make diagnosis easier

### Artifact
- ProcessBarMonitor-v1.0.2-macOS.zip
- SHA-256: `d4a8d2d5dbec76545df7789dd481f9e1086542dc44ea9280e2ce5a9d989c9c93`

### Notes
- CPU percentages are shown as raw per-process CPU usage and may exceed 100% on multicore Macs.
- CPU temperature is best-effort and may fall back to thermal state when no supported helper tool is available.
- This release ships as a macOS `.app` zipped artifact.
