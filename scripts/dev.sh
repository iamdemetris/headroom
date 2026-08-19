#!/usr/bin/env bash
# Install / refresh the developer build (Headroom Dev.app) without touching the
# stable app or its saved host list.
#
#   bash scripts/dev.sh         # build + swap in the dev app, then launch
#   DEV=1 bash scripts/build-app.sh   # build only, no install
#
# The dev app is fully separate from the stable app (different name, bundle id,
# and saved-data folder), so you can test changes freely and the stable app
# stays untouched.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/dist/Headroom Dev.app"
DST="$HOME/Applications/Headroom Dev.app"

echo "==> Building dev app"
DEV=1 bash "$ROOT/scripts/build-app.sh"

echo "==> Installing to $DST"
mkdir -p "$HOME/Applications"
rm -rf "$DST"
cp -R "$SRC" "$DST"

# Replace a running dev instance so the next activation shows the new build.
launchctl bootout "gui/$(id -u)/app.headroom.mac.dev" 2>/dev/null || true
pkill -x "Headroom Dev" 2>/dev/null || true
sleep 0.3

echo "==> Launching dev app"
open -a "$DST"
echo ""
echo "Headroom Dev should now be running (window titled \"Headroom Dev — DEV\")."
echo "Stable Headroom.app and its hosts.json are untouched."
