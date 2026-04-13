#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ProcessBarMonitor.app"
TARGET_DIR="$HOME/Applications"

TARGET_APP="$TARGET_DIR/$APP_NAME"

pkill -f "$TARGET_APP/Contents/MacOS/ProcessBarMonitor" || true
pkill -f "$ROOT/.build/.*/ProcessBarMonitor" || true
"$ROOT/build_app.sh" "$@"
mkdir -p "$TARGET_DIR"
rm -rf "$TARGET_APP"
cp -R "$ROOT/dist/$APP_NAME" "$TARGET_APP"
echo "Installed to $TARGET_APP"
open "$TARGET_APP"
