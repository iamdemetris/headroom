#!/usr/bin/env bash
# Developer ID sign, notarize, staple, and emit a DMG. Never prints Apple secrets.
# Uses the keychain profile created once with:
#   xcrun notarytool store-credentials "ludeshot-notary" --key AuthKey.p8 --key-id … --issuer …
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NOTARY_PROFILE="${NOTARY_PROFILE:-ludeshot-notary}"
VERSION="0.1.2"
APP="$ROOT/dist/Headroom.app"
ZIP="$ROOT/dist/Headroom-$VERSION.zip"
DMG="$ROOT/dist/Headroom-$VERSION.dmg"

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

echo ""
echo "Notarized:"
echo "  $APP"
echo "  $DMG"
