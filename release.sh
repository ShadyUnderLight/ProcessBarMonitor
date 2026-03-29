#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: ./release.sh <version> [build_number]"
  echo "Example: ./release.sh 1.0.1 2"
  exit 2
fi

VERSION_RAW="$1"
BUILD_NUMBER="${2:-1}"
VERSION="${VERSION_RAW#v}"
TAG="v$VERSION"
APP_NAME="ProcessBarMonitor"
ROOT="$(cd "$(dirname "$0")" && pwd)"
ASSET_DIR="$ROOT/release"
ASSET_NAME="$APP_NAME-$TAG-macOS.zip"
NOTES_FILE="$ASSET_DIR/release-notes-$TAG.md"
REPO="$(gh api user --jq .login)/$APP_NAME"

cd "$ROOT"

git diff --quiet || {
  echo "Working tree has uncommitted changes. Commit or stash them before releasing."
  exit 1
}

git diff --cached --quiet || {
  echo "Index has staged but uncommitted changes. Commit or stash them before releasing."
  exit 1
}

./build_app.sh "$VERSION" "$BUILD_NUMBER"
mkdir -p "$ASSET_DIR"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$ROOT/dist/$APP_NAME.app" "$ASSET_DIR/$ASSET_NAME"
SHA=$(shasum -a 256 "$ASSET_DIR/$ASSET_NAME" | awk '{print $1}')

cat > "$NOTES_FILE" <<EOF
## $APP_NAME $TAG

Packaged macOS release of $APP_NAME.

### Included
- Menu bar CPU / memory / thermal overview
- Top apps by CPU
- Top apps by memory
- Manual refresh
- Search and row count controls
- Launch at login toggle
- Improved Quit behavior for the menu bar app

### Artifact
- $ASSET_NAME
- SHA-256: \`$SHA\`

### Notes
- CPU temperature is best-effort and may fall back to thermal state when no supported helper tool is available.
- This release ships as a macOS `.app` zipped artifact.
EOF

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists locally."
else
  git tag -a "$TAG" -m "Release $TAG"
fi

git push origin main
git push origin "$TAG"

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" "$ASSET_DIR/$ASSET_NAME" --clobber --repo "$REPO"
  gh release edit "$TAG" --title "$APP_NAME $TAG" --notes-file "$NOTES_FILE" --latest --repo "$REPO"
else
  gh release create "$TAG" "$ASSET_DIR/$ASSET_NAME" --title "$APP_NAME $TAG" --notes-file "$NOTES_FILE" --latest --repo "$REPO"
fi

echo "Released $TAG"
gh release view "$TAG" --repo "$REPO" --json url,assets --jq '{url,assets:[.assets[]|{name,size:.size,url:.url}]}'
