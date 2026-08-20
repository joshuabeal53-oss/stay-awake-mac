#!/bin/bash
# Stay Awake — installs into ~/Applications. No admin password. No /Applications.
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/joshuabeal53-oss/stay-awake-mac/main"
DEST_DIR="$HOME/Applications"
APP="$DEST_DIR/Stay Awake.app"
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  HERE=""
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing $1"; exit 1; }; }
need /usr/bin/osacompile
need /usr/bin/osascript
need /usr/bin/caffeinate

mkdir -p "$DEST_DIR"
rm -rf "$APP"

TMP="$(mktemp -d /tmp/stayawake.XXXXXX)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

JS="$HERE/src/StayAwake.js"
ICON="$HERE/src/MenuIcon.png"
ICON_ON="$HERE/src/MenuIconFilled.png"
ICNS="$HERE/src/AppIcon.icns"

if [ ! -f "$JS" ]; then
  curl -fsSL "$REPO_RAW/src/StayAwake.js" -o "$TMP/StayAwake.js"
  JS="$TMP/StayAwake.js"
  curl -fsSL "$REPO_RAW/src/MenuIcon.png" -o "$TMP/MenuIcon.png" || true
  curl -fsSL "$REPO_RAW/src/MenuIconFilled.png" -o "$TMP/MenuIconFilled.png" || true
  curl -fsSL "$REPO_RAW/src/AppIcon.icns" -o "$TMP/AppIcon.icns" || true
  ICON="$TMP/MenuIcon.png"
  ICON_ON="$TMP/MenuIconFilled.png"
  ICNS="$TMP/AppIcon.icns"
fi

# Compile a real stay-open applet (Apple's stub, not a bash script).
# That avoids "you don't have permission to open this application."
/usr/bin/osacompile -x -l JavaScript -o "$APP" "$JS"

INFO="$APP/Contents/Info.plist"
if [ -f "$INFO" ]; then
  /usr/libexec/PlistBuddy -c 'Set :LSUIElement true' "$INFO" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' "$INFO" 2>/dev/null \
    || true
  /usr/libexec/PlistBuddy -c 'Set :CFBundleName Stay Awake' "$INFO" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Stay Awake' "$INFO" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c 'Add :CFBundleDisplayName string Stay Awake' "$INFO" 2>/dev/null \
    || true
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier app.stayawake.menu' "$INFO" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string app.stayawake.menu' "$INFO" 2>/dev/null \
    || true
fi

RES="$APP/Contents/Resources"
mkdir -p "$RES"
[ -f "$ICON" ] && cp "$ICON" "$RES/MenuIcon.png"
[ -f "$ICON_ON" ] && cp "$ICON_ON" "$RES/MenuIconFilled.png"
[ -f "$ICNS" ] && cp "$ICNS" "$RES/AppIcon.icns" && \
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile AppIcon' "$INFO" 2>/dev/null || true

# You own this folder — no sudo, no /Applications ACL.
chmod -R u+rwX "$APP" 2>/dev/null || true
chmod +x "$APP/Contents/MacOS/"* 2>/dev/null || true
/usr/bin/xattr -cr "$APP" 2>/dev/null || true

open "$APP"

/usr/bin/osascript -e 'display notification "Click the cup (or ●) next to the clock, then Turn On." with title "Stay Awake is in your menu bar"' >/dev/null 2>&1 || true

echo "Installed: $APP"
echo "Look at the top-right of the menu bar."
