#!/bin/bash
# Stay Awake installer — double-click this on your Mac.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

alert() {
  /usr/bin/osascript -e "display dialog $(printf %q "$1") buttons {\"OK\"} default button \"OK\" with title \"Stay Awake\"" >/dev/null
}

notify() {
  /usr/bin/osascript -e "display notification $(printf %q "$2") with title $(printf %q "$1")" >/dev/null || true
}

confirm=$(/usr/bin/osascript <<'APPLESCRIPT'
try
  set r to display dialog "Stay Awake will be installed in your Applications folder and appear in the menu bar (next to Wi-Fi and the clock).\n\nClick the cup to keep your Mac from sleeping." buttons {"Cancel", "Install"} default button "Install" with title "Stay Awake"
  return button returned of r
on error
  return "Cancel"
end try
APPLESCRIPT
)

if [ "$confirm" != "Install" ]; then
  exit 0
fi

SRC="$HERE/src"
if [ ! -d "$SRC" ]; then
  SRC="$HERE/../src"
fi

DEST_DIR="$HOME/Applications"
if mkdir -p "/Applications/Stay Awake.app/Contents/MacOS" 2>/dev/null; then
  DEST_DIR="/Applications"
fi
mkdir -p "$DEST_DIR"

APP="$DEST_DIR/Stay Awake.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

TMP="$(mktemp -d /tmp/stayawake.XXXXXX)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

COMPILED=0
if /usr/bin/xcrun --find swiftc >/dev/null 2>&1; then
  SDK="$(/usr/bin/xcrun --show-sdk-path 2>/dev/null || true)"
  if [ -n "$SDK" ]; then
    if /usr/bin/xcrun swiftc -parse-as-library -O -sdk "$SDK" -o "$TMP/StayAwake" "$SRC/StayAwake.swift" 2>"$TMP/swiftc.log"; then
      COMPILED=1
    fi
  else
    if /usr/bin/xcrun swiftc -parse-as-library -O -o "$TMP/StayAwake" "$SRC/StayAwake.swift" 2>"$TMP/swiftc.log"; then
      COMPILED=1
    fi
  fi
fi

if [ "$COMPILED" = "1" ]; then
  cp "$TMP/StayAwake" "$APP/Contents/MacOS/StayAwake"
  chmod +x "$APP/Contents/MacOS/StayAwake"
  cp "$SRC/Info.plist" "$APP/Contents/Info.plist"
else
  cat > "$APP/Contents/MacOS/StayAwake" <<'LAUNCHER'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
exec /usr/bin/osascript -l JavaScript "$DIR/../Resources/StayAwake.js"
LAUNCHER
  chmod +x "$APP/Contents/MacOS/StayAwake"
  cp "$SRC/StayAwake.js" "$APP/Contents/Resources/StayAwake.js"
  cp "$SRC/Info-jxa.plist" "$APP/Contents/Info.plist"
fi

if [ -f "$SRC/AppIcon.icns" ]; then
  cp "$SRC/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
if [ -f "$SRC/MenuIcon.png" ]; then
  cp "$SRC/MenuIcon.png" "$APP/Contents/Resources/MenuIcon.png"
fi
if [ -f "$SRC/MenuIconFilled.png" ]; then
  cp "$SRC/MenuIconFilled.png" "$APP/Contents/Resources/MenuIconFilled.png"
fi

echo -n 'APPL????' > "$APP/Contents/PkgInfo"

/usr/bin/xattr -cr "$APP" 2>/dev/null || true
/usr/bin/codesign --force --deep --sign - "$APP" 2>/dev/null || true

open "$APP"
notify "Stay Awake is in your menu bar" "Click the coffee cup near the clock, then Turn On."

/usr/bin/osascript -e 'tell application "Terminal" to close (every window whose name contains "Install Stay Awake")' >/dev/null 2>&1 || true
