#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SRC="$ROOT/dist/Headroom.app"
APP_DST="$HOME/Applications/Headroom.app"
PLIST_DST="$HOME/Library/LaunchAgents/app.headroom.mac.plist"

echo "==> Building"
bash "$ROOT/scripts/build-app.sh"

echo "==> Installing $APP_DST"
mkdir -p "$HOME/Applications"
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

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
    <string>$APP_DST/Contents/MacOS/Headroom</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)/app.headroom.mac" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
launchctl kickstart -k "gui/$(id -u)/app.headroom.mac"

echo ""
echo "Headroom is in the menu bar. Add your own SSH hosts there."
echo "Host lists stay in ~/Library/Application Support/Headroom/ and are never part of the repo."
