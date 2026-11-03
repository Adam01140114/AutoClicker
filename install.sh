#!/bin/bash
# Installs AutoClicker on this Mac. Either:
#   curl -fsSL https://raw.githubusercontent.com/Adam01140114/AutoClicker/main/install.sh | bash
#   bash install.sh /path/to/AutoClicker.zip
# No Xcode needed — this installs a prebuilt universal app.
set -euo pipefail

REPO="Adam01140114/AutoClicker"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ $# -ge 1 ]; then
  ZIP="$1"
  [ -f "$ZIP" ] || { echo "No such file: $ZIP" >&2; exit 1; }
else
  ZIP="$TMP/AutoClicker.zip"
  echo "Downloading the latest release…"
  curl -fsSL "https://github.com/$REPO/releases/latest/download/AutoClicker.zip" -o "$ZIP"
fi

ditto -x -k "$ZIP" "$TMP/unpacked"
APP="$TMP/unpacked/AutoClicker.app"
[ -d "$APP" ] || { echo "That archive does not contain AutoClicker.app" >&2; exit 1; }

# A bundle that arrived over the network is quarantined; clearing it here keeps
# macOS from refusing to open an app that is only ad-hoc signed.
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

DEST=/Applications
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"
pkill -x AutoClicker 2>/dev/null || true
rm -rf "$DEST/AutoClicker.app"
ditto "$APP" "$DEST/AutoClicker.app"

echo "Installed $DEST/AutoClicker.app"
open "$DEST/AutoClicker.app"
echo
echo "Grant it Accessibility and Input Monitoring when it asks"
echo "(System Settings > Privacy & Security), then let it relaunch."
