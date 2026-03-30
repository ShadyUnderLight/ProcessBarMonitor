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
CHECKSUM_FILE="$ASSET_DIR/$APP_NAME-$TAG-SHA256SUMS.txt"

required_commands=(git gh swift shasum ditto)
for cmd in "${required_commands[@]}"; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd"
    exit 1
  }
done

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated. Run: gh auth login"
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\\.[0-9]+\\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid version: $VERSION_RAW"
  echo "Expected format: X.Y.Z or vX.Y.Z (optional prerelease/build suffix)"
  exit 2
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Build number must be an integer. Received: $BUILD_NUMBER"
  exit 2
fi

cd "$ROOT"

git diff --quiet || {
  echo "Working tree has uncommitted changes. Commit or stash them before releasing."
  exit 1
}

git diff --cached --quiet || {
  echo "Index has staged but uncommitted changes. Commit or stash them before releasing."
  exit 1
}

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "main" && "${ALLOW_NON_MAIN_RELEASE:-0}" != "1" ]]; then
  echo "Releases are restricted to main by default. Current branch: $CURRENT_BRANCH"
  echo "Set ALLOW_NON_MAIN_RELEASE=1 to override intentionally."
  exit 1
fi

TAG_EXISTS_LOCAL=0
if git rev-parse "$TAG" >/dev/null 2>&1; then
  TAG_EXISTS_LOCAL=1
  TAG_COMMIT="$(git rev-parse "$TAG^{commit}")"
  HEAD_COMMIT="$(git rev-parse HEAD)"
  if [[ "$TAG_COMMIT" != "$HEAD_COMMIT" ]]; then
    echo "Tag $TAG already exists but does not point to HEAD."
    exit 1
  fi
fi

REMOTE_URL="$(git remote get-url origin)"
if [[ "$REMOTE_URL" =~ github\\.com[:/]([^/]+)/([^/.]+)(\\.git)?$ ]]; then
  REPO="${match[1]}/${match[2]}"
else
  echo "Unable to derive GitHub repo from origin URL: $REMOTE_URL"
  exit 1
fi

./build_app.sh "$VERSION" "$BUILD_NUMBER" --configuration release
./scripts/validate_app_bundle.sh "$ROOT/dist/$APP_NAME.app"

mkdir -p "$ASSET_DIR"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$ROOT/dist/$APP_NAME.app" "$ASSET_DIR/$ASSET_NAME"
SHA=$(shasum -a 256 "$ASSET_DIR/$ASSET_NAME" | awk '{print $1}')
printf "%s  %s\n" "$SHA" "$ASSET_NAME" > "$CHECKSUM_FILE"

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
- $(basename "$CHECKSUM_FILE")
- SHA-256: $SHA

### Notes
- CPU temperature is best-effort and may fall back to thermal state when no supported helper tool is available.
- This release ships as a macOS .app zipped artifact.
EOF

if [[ "$TAG_EXISTS_LOCAL" -eq 0 ]]; then
  git tag -a "$TAG" -m "Release $TAG"
fi

if git ls-remote --tags origin "refs/tags/$TAG" | grep -q "$TAG"; then
  echo "Tag $TAG already exists on origin."
else
  git push origin "$TAG"
fi

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" "$ASSET_DIR/$ASSET_NAME" "$CHECKSUM_FILE" --clobber --repo "$REPO"
  gh release edit "$TAG" --title "$APP_NAME $TAG" --notes-file "$NOTES_FILE" --latest --repo "$REPO"
else
  gh release create "$TAG" "$ASSET_DIR/$ASSET_NAME" "$CHECKSUM_FILE" --title "$APP_NAME $TAG" --notes-file "$NOTES_FILE" --latest --repo "$REPO"
fi

echo "Released $TAG"
gh release view "$TAG" --repo "$REPO" --json url,assets --jq '{url,assets:[.assets[]|{name,size:.size,url:.url}]}'
