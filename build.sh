#!/bin/bash
# Builds AutoClicker.app and installs it into /Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/AutoClicker.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Build a universal binary when both slices compile, so one copy of the app
# runs on Apple Silicon and Intel without rebuilding on the other machine.
BIN="$APP/Contents/MacOS/AutoClicker"
SLICES=()
for arch in arm64 x86_64; do
  if swiftc -O -target "$arch-apple-macos14.0" -o "build/slice-$arch" Sources/*.swift 2>/dev/null; then
    SLICES+=("build/slice-$arch")
  fi
done
case ${#SLICES[@]} in
  0) swiftc -O -target "$(uname -m)-apple-macos14.0" -o "$BIN" Sources/*.swift ;;
  1) cp "${SLICES[0]}" "$BIN" ;;
  *) lipo -create "${SLICES[@]}" -output "$BIN" ;;
esac
rm -f build/slice-arm64 build/slice-x86_64
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

# package.sh sets this: build the bundle but leave /Applications alone.
if [ "${AUTOCLICKER_NO_INSTALL:-0}" = "1" ]; then
  echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/AutoClicker"))"
  exit 0
fi

DEST=/Applications
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"
pkill -x AutoClicker 2>/dev/null || true
rm -rf "$DEST/AutoClicker.app"
ditto "$APP" "$DEST/AutoClicker.app"
echo "Installed $DEST/AutoClicker.app"
