#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Headroom"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
CONTENTS="$APP/Contents"
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/{print $2; exit}')}"

echo "==> Cleaning"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

echo "==> Compiling"
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
  "$ROOT/Sources/RootView.swift" \
  "$ROOT/Sources/AppDelegate.swift" \
  "$ROOT/Sources/main.swift"

cp "$ROOT/Resources/collector.py" "$CONTENTS/Resources/collector.py"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Headroom</string>
  <key>CFBundleDisplayName</key><string>Headroom</string>
  <key>CFBundleExecutable</key><string>Headroom</string>
  <key>CFBundleIdentifier</key><string>app.headroom.mac</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.2</string>
  <key>CFBundleVersion</key><string>3</string>
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
