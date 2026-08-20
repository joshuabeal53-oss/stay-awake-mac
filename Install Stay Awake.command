#!/bin/bash
# Stay Awake installer — double-click this on your Mac.
# Installs into ~/Applications (your home folder). Never needs an admin password.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

confirm=$(/usr/bin/osascript <<'APPLESCRIPT'
try
  set r to display dialog "Stay Awake will be installed in your home Applications folder (~/Applications) and appear in the menu bar.\n\nNo admin password. Click the cup (or a dot) next to the clock, then Turn On." buttons {"Cancel", "Install"} default button "Install" with title "Stay Awake"
  return button returned of r
on error
  return "Cancel"
end try
APPLESCRIPT
)

if [ "$confirm" != "Install" ]; then
  exit 0
fi

if [ -f "$HERE/install.sh" ]; then
  bash "$HERE/install.sh"
elif [ -f "$HERE/../install.sh" ]; then
  bash "$HERE/../install.sh"
else
  curl -fsSL "https://raw.githubusercontent.com/joshuabeal53-oss/stay-awake-mac/main/install.sh" | bash
fi

/usr/bin/osascript -e 'tell application "Terminal" to close (every window whose name contains "Install Stay Awake")' >/dev/null 2>&1 || true
