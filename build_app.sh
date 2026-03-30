#!/bin/zsh
set -euo pipefail

APP_NAME="ProcessBarMonitor"
BUNDLE_ID="ai.openclaw.ProcessBarMonitor"
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT/dist/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
VERSION="1.0.0"
BUILD_NUMBER="1"
CONFIGURATION="${CONFIGURATION:-release}"
CLEAN_BUILD=0

usage() {
  cat <<EOF
Usage: ./build_app.sh [version] [build_number] [--configuration <release|debug>] [--clean]

Examples:
  ./build_app.sh
  ./build_app.sh 1.0.2 3
  ./build_app.sh 1.0.2 3 --configuration debug
EOF
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      [[ $# -ge 2 ]] || { echo "--configuration requires a value"; exit 2; }
      CONFIGURATION="$2"
      shift 2
      ;;
    --configuration=*)
      CONFIGURATION="${1#*=}"
      shift
      ;;
    --clean)
      CLEAN_BUILD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      usage
      exit 2
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [[ ${#POSITIONAL[@]} -ge 1 ]]; then VERSION="${POSITIONAL[1]}"; fi
if [[ ${#POSITIONAL[@]} -ge 2 ]]; then BUILD_NUMBER="${POSITIONAL[2]}"; fi
if [[ ${#POSITIONAL[@]} -gt 2 ]]; then
  echo "Too many positional arguments."
  usage
  exit 2
fi

if [[ "$CONFIGURATION" != "release" && "$CONFIGURATION" != "debug" ]]; then
  echo "Invalid configuration: $CONFIGURATION (expected: release or debug)"
  exit 2
fi

cd "$ROOT"
if [[ "$CLEAN_BUILD" -eq 1 ]]; then
  rm -rf "$ROOT/dist"
fi

swift scripts/generate_icon.swift
swift build --configuration "$CONFIGURATION"

BIN_DIR="$(swift build --configuration "$CONFIGURATION" --show-bin-path)"
EXECUTABLE_PATH="$BIN_DIR/$APP_NAME"
RESOURCE_BUNDLE="$(find "$BIN_DIR" -maxdepth 1 -type d -name "*_${APP_NAME}.bundle" | head -n 1)"

[[ -x "$EXECUTABLE_PATH" ]] || { echo "Missing built executable: $EXECUTABLE_PATH"; exit 1; }
[[ -f "$ROOT/Resources/ProcessBarMonitor.icns" ]] || { echo "Missing icon file."; exit 1; }
[[ -n "$RESOURCE_BUNDLE" ]] || { echo "Missing SwiftPM resource bundle in $BIN_DIR"; exit 1; }

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"
cp "$ROOT/Resources/ProcessBarMonitor.icns" "$RESOURCES_DIR/ProcessBarMonitor.icns"
cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/$(basename "$RESOURCE_BUNDLE")"
cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key><string>ProcessBarMonitor</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF
plutil -lint "$APP_DIR/Contents/Info.plist" >/dev/null

echo "Built app bundle at: $APP_DIR"
echo "Version: $VERSION ($BUILD_NUMBER), configuration: $CONFIGURATION"
