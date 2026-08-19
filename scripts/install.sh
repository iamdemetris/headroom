#!/usr/bin/env bash
# Install / refresh the stable Headroom app into ~/Applications, register it to
# launch at login, and start it. Saved hosts are preserved (hosts.json lives
# outside the app bundle).
#
# Prefers the notarized release DMG (same source the self-updater uses) when the
# version matches scripts/version.txt; otherwise falls back to a local build.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(cat "$ROOT/scripts/version.txt")"
GH_REPO="${GH_REPO:-iamdemetris/headroom}"
APP_SRC="$ROOT/dist/Headroom.app"
APP_DST="$HOME/Applications/Headroom.app"
PLIST_DST="$HOME/Library/LaunchAgents/app.headroom.mac.plist"

mkdir -p "$HOME/Applications" "$ROOT/dist"

echo "==> Checking for notarized release $VERSION"
DMG_URL="https://github.com/$GH_REPO/releases/download/v$VERSION/Headroom-$VERSION.dmg"
DMG_LOCAL="$ROOT/dist/Headroom-$VERSION.dmg"
if [[ -f "$DMG_LOCAL" ]] || curl -fL --retry 2 -o "$DMG_LOCAL" "$DMG_URL" 2>/dev/null; then
  echo "==> Using notarized DMG: $DMG_LOCAL"
  MOUNT="$ROOT/dist/.install-mount"
  rm -rf "$MOUNT"; mkdir -p "$MOUNT"
  hdiutil attach "$DMG_LOCAL" -nobrowse -readonly -mountpoint "$MOUNT" >/dev/null
  trap 'hdiutil detach "$MOUNT" -quiet >/dev/null 2>&1 || true' EXIT
  NEW_APP="$(find "$MOUNT" -maxdepth 1 -name '*.app' | head -1)"
  rm -rf "$APP_DST"
  cp -R "$NEW_APP" "$APP_DST"
else
  echo "==> No release DMG found; building locally"
  bash "$ROOT/scripts/build-app.sh"
  echo "==> Installing $APP_DST"
  rm -rf "$APP_DST"
  cp -R "$APP_SRC" "$APP_DST"
fi

# Leave leftover prototype bits behind if this machine once ran them.
launchctl bootout "gui/$(id -u)/com.lude.vps-pulse" 2>/dev/null || true
pkill -x VpsPulse 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.lude.vps-pulse.plist"
rm -rf "$HOME/Applications/VpsPulse.app"

echo "==> Launch at login"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST_DST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>app.headroom.mac</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-g</string>
    <string>-a</string>
    <string>$APP_DST</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)/app.headroom.mac" 2>/dev/null || true
pkill -x Headroom 2>/dev/null || true
sleep 0.3
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
# open via LaunchServices so the extra actually lands in the menu bar
open -a "$APP_DST"

echo ""
echo "Headroom should now be in the menu bar (installed from the notarized release)."
echo "Host lists stay in ~/Library/Application Support/Headroom/ and are never part of the repo."
