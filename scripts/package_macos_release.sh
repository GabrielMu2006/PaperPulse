#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DERIVED_DATA="${DERIVED_DATA_PATH:-/private/tmp/PaperPulseMacReleaseDerivedData}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/releases}"
APP_PATH="$DERIVED_DATA/Build/Products/Release/PaperPulse.app"
ARCHIVE_PATH="$OUTPUT_DIR/PaperPulse-v${VERSION}-macOS-arm64.zip"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must use major.minor.patch format, for example: 0.1.0" >&2
  exit 2
fi

mkdir -p "$OUTPUT_DIR"

env \
  CLANG_MODULE_CACHE_PATH=/private/tmp/PaperPulseMacClangModuleCache \
  SWIFTPM_CONFIG_PATH=/private/tmp/PaperPulseMacSwiftPMConfig \
  SWIFTPM_CACHE_PATH=/private/tmp/PaperPulseMacSwiftPMCache \
  xcodebuild \
  -project "$ROOT/PaperPulse.xcodeproj" \
  -scheme PaperPulseMac \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED_DATA" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  build CODE_SIGNING_ALLOWED=NO

if [[ ! -d "$APP_PATH" ]]; then
  echo "Release app was not produced at: $APP_PATH" >&2
  exit 1
fi

ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
if [[ "$ACTUAL_VERSION" != "$VERSION" ]]; then
  echo "Release version mismatch: expected $VERSION, found $ACTUAL_VERSION" >&2
  exit 1
fi

rm -f "$ARCHIVE_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ARCHIVE_PATH"

echo "Release archive: $ARCHIVE_PATH"
