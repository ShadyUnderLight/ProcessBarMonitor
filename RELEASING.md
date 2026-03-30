# RELEASING.md

Maintainer-only release workflow for ProcessBarMonitor.

## Create a release

```bash
./release.sh 1.0.1 2
```

Arguments:
- first argument: semantic version, with or without the `v` prefix
- second argument: build number (optional, defaults to `1`)

Examples:

```bash
./release.sh 1.0.1
./release.sh v1.0.2 3
```

## What the script does

- builds the app bundle in `release` configuration
- stamps version/build into `Info.plist`
- validates the generated `.app` bundle contents
- zips `dist/ProcessBarMonitor.app`
- writes `SHA256SUMS` for the zip
- creates or updates the Git tag
- creates or updates the GitHub Release
- uploads the zipped release asset and checksum file
- marks the release as latest

## Preconditions

- working tree must be clean
- `gh` must be installed and authenticated
- you need permission to push tags and create releases for the repo
- default release branch is `main` (override intentionally with `ALLOW_NON_MAIN_RELEASE=1`)

## Notes

- release assets are written to `release/`
- release notes are generated into `release/release-notes-vX.Y.Z.md`
- checksum file is generated as `release/ProcessBarMonitor-vX.Y.Z-SHA256SUMS.txt`
- current release helper script: `release.sh`
- bundle validation helper: `scripts/validate_app_bundle.sh`
