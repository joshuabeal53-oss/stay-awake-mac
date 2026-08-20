# Stay Awake for Mac

Menu bar app that keeps your Mac from sleeping. Installs into **~/Applications** (your home folder) so macOS never asks for an admin password.

## Install (this is the one that works)

Open **Terminal** and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/joshuabeal53-oss/stay-awake-mac/main/install.sh | bash
```

Then look at the **top-right of the menu bar** (next to Wi-Fi). Click the cup or the ● / ○ dot → **Turn On**.

That command compiles a real Mac applet with Apple’s own `osacompile`. No Gatekeeper dance, no `/Applications` privileges.

## If you already have a broken copy

Quit it if it’s running, delete `/Applications/Stay Awake.app` and `~/Applications/Stay Awake.app` if they exist, then run the curl command above.

## What it does

Uses `/usr/bin/caffeinate` (same idea as Amphetamine / Caffeine). Optional cursor nudge every 10 minutes. Closing the lid still sleeps the Mac.

## Uninstall

Menu bar icon → Quit Stay Awake, then delete `~/Applications/Stay Awake.app`.
