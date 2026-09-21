#!/usr/bin/env bash
# Build a Release QuotAI.app and wrap it in a compressed DMG for GitHub Releases.
#
# Optional (set when Developer ID + notary profile exist):
#   QUOTAI_SIGN_IDENTITY   e.g. "Developer ID Application: Your Name (TEAMID)"
#   QUOTAI_NOTARY_PROFILE  keychain profile for `xcrun notarytool`
#   RELEASE_TAG            e.g. v0.5.0 — must match MARKETING_VERSION in project.yml
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

SCHEME=QuotAI
PROJECT=QuotAI.xcodeproj
DESTINATION="${DESTINATION:-platform=macOS,arch=arm64}"
DERIVED_DATA="${DERIVED_DATA:-.build/DerivedData}"
CONFIG=Release
APP_NAME=QuotAI

VERSION="$(
  sed -n 's/^[[:space:]]*MARKETING_VERSION:[[:space:]]*"\([^"]*\)".*/\1/p' project.yml | head -1
)"
if [[ -z "$VERSION" ]]; then
  echo "error: could not read MARKETING_VERSION from project.yml" >&2
  exit 1
fi

if [[ -n "${RELEASE_TAG:-}" ]]; then
  EXPECTED="${RELEASE_TAG#v}"
  if [[ "$EXPECTED" != "$VERSION" ]]; then
    echo "error: tag ${RELEASE_TAG} (v${EXPECTED}) != MARKETING_VERSION ${VERSION} in project.yml" >&2
    exit 1
  fi
fi

DIST_DIR="$ROOT/dist"
STAGE_DIR="$DIST_DIR/stage"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"

sign_app_bundle() {
  local app_path="$1"
  local identity="$2"
  local framework="$app_path/Contents/Frameworks/QuotAICore.framework"
  local executable="$app_path/Contents/MacOS/$APP_NAME"

  local -a sign_opts=(--force --sign "$identity" --timestamp=none)
  if [[ "$identity" != "-" ]]; then
    sign_opts+=(--options runtime)
  fi

  if [[ -d "$framework" ]]; then
    if [[ -f "$framework/Versions/A/QuotAICore" ]]; then
      codesign "${sign_opts[@]}" "$framework/Versions/A/QuotAICore"
    fi
    codesign "${sign_opts[@]}" "$framework"
  fi
  codesign "${sign_opts[@]}" "$executable"
  codesign "${sign_opts[@]}" "$app_path"
  codesign --verify --deep --strict "$app_path"
}

echo "→ QuotAI ${VERSION} (${CONFIG}, ${DESTINATION})"

xcodegen generate

# Ad-hoc Release builds cannot load an embedded framework when hardened runtime
# is on — dyld rejects QuotAICore with "different Team IDs". Developer ID builds
# keep hardened runtime and are re-signed inside-out after xcodebuild.
SIGN_IDENTITY="${QUOTAI_SIGN_IDENTITY:--}"
HARDENED_RUNTIME=NO
if [[ -n "${QUOTAI_SIGN_IDENTITY:-}" ]]; then
  HARDENED_RUNTIME=YES
fi

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  ENABLE_HARDENED_RUNTIME="$HARDENED_RUNTIME" \
  build

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIG/${APP_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "error: ${APP_PATH} not found after build" >&2
  exit 1
fi

echo "→ codesign (${SIGN_IDENTITY})"
sign_app_bundle "$APP_PATH" "$SIGN_IDENTITY"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

rm -f "$DMG_PATH"
echo "→ hdiutil create ${DMG_PATH}"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "${QUOTAI_NOTARY_PROFILE:-}" ]]; then
  echo "→ notarize (${QUOTAI_NOTARY_PROFILE})"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$QUOTAI_NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
fi

rm -rf "$STAGE_DIR"

echo ""
echo "Created: ${DMG_PATH}"
echo "SHA256:  $(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
if [[ -z "${QUOTAI_SIGN_IDENTITY:-}" ]]; then
  echo ""
  echo "Note: ad-hoc build (hardened runtime off). Set QUOTAI_SIGN_IDENTITY + QUOTAI_NOTARY_PROFILE for Gatekeeper-safe distribution."
fi
