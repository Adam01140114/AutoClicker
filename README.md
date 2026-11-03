# AutoClicker

A small macOS macro recorder. Record a sequence of clicks and keystrokes, then
replay it as many times as you like, at half, normal or double speed. Press
**Esc** at any point to stop playback.

Native Swift and SwiftUI, no dependencies. macOS 14 or later.

## Setting it up on another Mac

You need Xcode's command line tools for `swiftc`:

```bash
xcode-select --install
```

Then clone and build — the script compiles the app and installs it into
`/Applications` (or `~/Applications` if that isn't writable):

```bash
git clone https://github.com/Adam01140114/AutoClicker.git
cd AutoClicker && ./build.sh
```

Building on each Mac rather than copying the `.app` across keeps the binary
native to that machine's architecture and avoids Gatekeeper quarantining a
bundle that arrived over the network.

## Permissions

macOS will not let any app replay input without permission, so on first launch
AutoClicker asks for two, under System Settings → Privacy & Security:

- **Accessibility** — to replay clicks and keystrokes
- **Input Monitoring** — to record keystrokes in the first place

These are granted per machine, so the other Mac needs its own grants. The app
shows which are missing and links straight to the right settings pane. macOS
usually only applies a new grant after a restart; the app offers to relaunch
itself.

If `build.sh` finds an Apple Development or Developer ID signing identity in
your keychain it signs with that, which means macOS remembers the permissions
across rebuilds. Without one it falls back to ad-hoc signing, and you may have
to re-grant after each rebuild.

## Layout

```
Sources/MacroEngine.swift   recording, playback, timing, the Esc stop
Sources/ControlView.swift   the floating Record / Stop / Play panel
Sources/SettingsView.swift  repeat count and playback speed
Sources/Permissions.swift   Accessibility + Input Monitoring state and prompts
Sources/AppDelegate.swift   window setup and defaults
tools/make-icon.swift       draws the app icon; build.sh turns it into .icns
build.sh                    build, sign, install
```
