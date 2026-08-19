#!/usr/bin/env bash
# Build Headroom as either the stable app or the developer app.
#
# Usage:
#   bash scripts/build-app.sh                 # stable   -> dist/Headroom.app
#   DEV=1 bash scripts/build-app.sh           # developer-> dist/Headroom Dev.app
#
# Stable vs developer differences:
#   * App name + bundle id differ, so the dev build never tramples the
#     installed stable app (or its saved host list).
#   * The dev app shows a "DEV" suffix in the window title so you always know
#     which build you're looking at.
#   * The dev app skips the installed-app relaunch/update wiring only if you
#     don't set STABLE=1; the update check itself is harmless and useful in dev.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"

if [[ "${DEV:-0}" == "1" ]]; then
  APP_NAME="Headroom Dev"
  BUNDLE_ID="app.headroom.mac.dev"
  DISPLAY_NAME="Headroom Dev"
else
  APP_NAME="Headroom"
  BUNDLE_ID="app.headroom.mac"
  DISPLAY_NAME="Headroom"
fi

IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/{print $2; exit}')}"

# Keep app version + git build in sync between the binary and Info.plist.
bash "$ROOT/scripts/emit-appinfo.sh"

APP="$DIST/$APP_NAME.app"
CONTENTS="$APP/Contents"

echo "==> Building $APP_NAME"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

xcrun swiftc \
  -swift-version 6 \
  -target arm64-apple-macosx14.0 \
  -O \
  -framework AppKit \
  -framework SwiftUI \
  -framework UserNotifications \
  -o "$CONTENTS/MacOS/$APP_NAME" \
  "$ROOT/Sources/Theme.swift" \
  "$ROOT/Sources/Models.swift" \
  "$ROOT/Sources/HostStore.swift" \
  "$ROOT/Sources/SSHCollector.swift" \
  "$ROOT/Sources/FleetModel.swift" \
  "$ROOT/Sources/AppInfo.swift" \
  "$ROOT/Sources/Updater.swift" \
  "$ROOT/Sources/UpdateManager.swift" \
  "$ROOT/Sources/UpdateShell.swift" \
  "$ROOT/Sources/RootView.swift" \
  "$ROOT/Sources/AppDelegate.swift" \
  "$ROOT/Sources/main.swift"

cp "$ROOT/Resources/collector.py" "$CONTENTS/Resources/collector.py"
cp "$ROOT/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"

VERSION="$(cat "$ROOT/scripts/version.txt")"
BUILD="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo dev)"
if [[ "${DEV:-0}" == "1" ]]; then
  BUILD="dev-$BUILD"
fi

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><false/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
</dict>
</plist>
PLIST

SIGN_ARGS=(--force --deep --options runtime --entitlements "$ROOT/Resources/Headroom.entitlements")
if [[ "${RELEASE_SIGNING:-}" == "1" ]]; then
  SIGN_ARGS+=(--timestamp)
fi

if [[ -n "$IDENTITY" ]]; then
  echo "==> Signing with $IDENTITY"
  codesign "${SIGN_ARGS[@]}" --sign "$IDENTITY" "$APP"
else
  echo "==> No Developer ID; ad-hoc sign (local only)"
  codesign --force --deep --sign - "$APP"
fi

echo "Built $APP"
