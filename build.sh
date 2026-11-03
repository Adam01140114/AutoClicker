#!/bin/bash
# Builds AutoClicker.app and installs it into /Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/AutoClicker.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -target "$(uname -m)-apple-macos14.0" \
  -o "$APP/Contents/MacOS/AutoClicker" Sources/*.swift
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ ! -f build/AppIcon.icns ]; then
  rm -rf build/AppIcon.iconset
  swift tools/make-icon.swift build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Sign with a real identity when there is one so macOS remembers the Accessibility /
# Input Monitoring permissions across rebuilds; fall back to ad-hoc signing.
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development|Developer ID/ {print $2; exit}')
codesign --force --sign "${IDENTITY:--}" "$APP" 2>/dev/null || codesign --force --sign - "$APP"

DEST=/Applications
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"
pkill -x AutoClicker 2>/dev/null || true
rm -rf "$DEST/AutoClicker.app"
ditto "$APP" "$DEST/AutoClicker.app"
echo "Installed $DEST/AutoClicker.app"
