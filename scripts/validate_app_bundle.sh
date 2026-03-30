#!/bin/zsh
set -euo pipefail

APP_PATH="${1:-dist/ProcessBarMonitor.app}"

fail() {
  echo "Validation failed: $1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "Missing file: $path"
}

require_dir() {
  local path="$1"
  [[ -d "$path" ]] || fail "Missing directory: $path"
}

plist_value() {
  local key="$1"
  local plist="$2"
  /usr/libexec/PlistBuddy -c "Print $key" "$plist" 2>/dev/null || true
}

require_dir "$APP_PATH"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXECUTABLE="$APP_PATH/Contents/MacOS/ProcessBarMonitor"
ICON_FILE="$APP_PATH/Contents/Resources/ProcessBarMonitor.icns"

require_file "$INFO_PLIST"
require_file "$EXECUTABLE"
require_file "$ICON_FILE"
[[ -x "$EXECUTABLE" ]] || fail "Executable is not marked executable: $EXECUTABLE"

CF_BUNDLE_NAME="$(plist_value "CFBundleName" "$INFO_PLIST")"
CF_BUNDLE_EXEC="$(plist_value "CFBundleExecutable" "$INFO_PLIST")"
CF_BUNDLE_ID="$(plist_value "CFBundleIdentifier" "$INFO_PLIST")"
CF_BUNDLE_SHORT_VERSION="$(plist_value "CFBundleShortVersionString" "$INFO_PLIST")"
CF_BUNDLE_VERSION="$(plist_value "CFBundleVersion" "$INFO_PLIST")"
LS_UI_ELEMENT="$(plist_value "LSUIElement" "$INFO_PLIST")"

[[ "$CF_BUNDLE_NAME" == "ProcessBarMonitor" ]] || fail "Unexpected CFBundleName: $CF_BUNDLE_NAME"
[[ "$CF_BUNDLE_EXEC" == "ProcessBarMonitor" ]] || fail "Unexpected CFBundleExecutable: $CF_BUNDLE_EXEC"
[[ "$CF_BUNDLE_ID" == "ai.openclaw.ProcessBarMonitor" ]] || fail "Unexpected CFBundleIdentifier: $CF_BUNDLE_ID"
[[ -n "$CF_BUNDLE_SHORT_VERSION" ]] || fail "Missing CFBundleShortVersionString"
[[ -n "$CF_BUNDLE_VERSION" ]] || fail "Missing CFBundleVersion"
[[ "$LS_UI_ELEMENT" == "true" ]] || fail "LSUIElement must be true for menu bar app"

RESOURCE_BUNDLE="$(find "$APP_PATH/Contents/Resources" -maxdepth 1 -type d -name "*_ProcessBarMonitor.bundle" | head -n 1)"
[[ -n "$RESOURCE_BUNDLE" ]] || fail "SwiftPM resource bundle was not packaged in app resources"

require_file "$RESOURCE_BUNDLE/Info.plist"
require_file "$RESOURCE_BUNDLE/en.lproj/Localizable.strings"
if [[ ! -f "$RESOURCE_BUNDLE/zh-Hans.lproj/Localizable.strings" && ! -f "$RESOURCE_BUNDLE/zh-hans.lproj/Localizable.strings" ]]; then
  fail "Missing zh-Hans localization file in resource bundle"
fi

echo "Validation passed: $APP_PATH"
echo "Version: $CF_BUNDLE_SHORT_VERSION ($CF_BUNDLE_VERSION)"
echo "Resource bundle: $(basename "$RESOURCE_BUNDLE")"
