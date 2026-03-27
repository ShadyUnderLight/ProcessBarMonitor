#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ProcessBarMonitor.app"
TARGET_DIR="$HOME/Applications"

pkill -f '/Users/mn/Applications/ProcessBarMonitor.app/Contents/MacOS/ProcessBarMonitor' || true
pkill -f '/Users/mn/.openclaw/workspace/ProcessBarMonitor/.build/.*/ProcessBarMonitor' || true
"$ROOT/build_app.sh"
mkdir -p "$TARGET_DIR"
rm -rf "$TARGET_DIR/$APP_NAME"
cp -R "$ROOT/dist/$APP_NAME" "$TARGET_DIR/$APP_NAME"
echo "Installed to $TARGET_DIR/$APP_NAME"
open "$TARGET_DIR/$APP_NAME"
