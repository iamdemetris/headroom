#!/usr/bin/env bash
# Developer ID sign, notarize, staple, emit a DMG, and publish to GitHub
# Releases. Never prints Apple secrets.
# Uses the keychain profile created once with:
#   xcrun notarytool store-credentials "ludeshot-notary" --key AuthKey.p8 --key-id … --issuer …
# Requires gh to be authenticated (for publishing releases + uploading the DMG).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NOTARY_PROFILE="${NOTARY_PROFILE:-ludeshot-notary}"
GH_REPO="${GH_REPO:-iamdemetris/headroom}"
# Single source of truth for the version (scripts/version.txt).
VERSION="$(cat "$ROOT/scripts/version.txt")"
TAG="v$VERSION"
APP="$ROOT/dist/Headroom.app"
ZIP="$ROOT/dist/Headroom-$VERSION.zip"
DMG="$ROOT/dist/Headroom-$VERSION.dmg"

echo "==> Building $APP (version $VERSION)"
export RELEASE_SIGNING=1
bash "$ROOT/scripts/build-app.sh"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=4 "$APP" 2>&1 || true

echo "==> Zipping for Notary"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Notarizing (keychain profile: $NOTARY_PROFILE)"
caffeinate -i xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling"
xcrun stapler staple "$APP"

echo "==> Building DMG"
rm -f "$DMG"
hdiutil create -volname Headroom -srcfolder "$APP" -ov -format UDZO "$DMG"
echo "==> Notarizing DMG"
caffeinate -i xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

echo "==> Publishing GitHub release $TAG"
if ! gh release view "$TAG" --repo "$GH_REPO" >/dev/null 2>&1; then
  gh release create "$TAG" "$DMG" \
    --repo "$GH_REPO" \
    --title "Headroom $VERSION" \
    --notes "See the commit(s) since v$(git describe --abbrev=0 --tags 2>/dev/null || echo 0.0) for details."
else
  # Release already exists (e.g. re-run to re-notarize): update assets.
  gh release upload "$TAG" "$DMG" --repo "$GH_REPO" --clobber
fi

echo ""
echo "Notarized + published:"
echo "  $APP"
echo "  $DMG"
echo "  https://github.com/$GH_REPO/releases/tag/$TAG"
echo "The stable Headroom app will now notify about this update."
