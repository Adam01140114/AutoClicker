# AutoClicker

A small macOS macro recorder. Record a sequence of clicks and keystrokes, then
replay it as many times as you like, at half, normal or double speed. Press
**Esc** at any point to stop playback.

Native Swift and SwiftUI, no dependencies. macOS 14 or later.

## Install

One line in Terminal, on any Mac running macOS 14 or later:

```bash
curl -fsSL https://raw.githubusercontent.com/Adam01140114/AutoClicker/main/install.sh | bash
```

That downloads the latest release, installs it into `/Applications` and opens
it. No Xcode, no git, no clone. The same line installs updates later.

The release is a universal build, so it runs on Apple Silicon and Intel alike.
The installer clears the quarantine flag macOS puts on anything downloaded,
which is what otherwise makes it refuse to open an app that is only ad-hoc
signed.

## Building it yourself

Only needed if you are changing the code. Requires Xcode's command line tools
for `swiftc`:

```bash
xcode-select --install
git clone https://github.com/Adam01140114/AutoClicker.git
cd AutoClicker && ./build.sh
```

`build.sh` compiles both architectures, lipos them into one universal binary,
signs the bundle and installs it. To cut a new release for the other Mac to
pick up, run `./release.sh`.

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
build.sh                    build universal, sign, install
package.sh                  build without installing, zip the bundle
install.sh                  the one-liner: fetch a release and install it
release.sh                  build, zip and publish a GitHub release
```
