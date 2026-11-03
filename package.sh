#!/bin/bash
# Builds a universal AutoClicker.app and zips it ready to hand to another Mac.
# Does not touch /Applications on this machine.
set -euo pipefail
cd "$(dirname "$0")"

AUTOCLICKER_NO_INSTALL=1 ./build.sh

rm -f build/AutoClicker.zip
ditto -c -k --keepParent build/AutoClicker.app build/AutoClicker.zip
echo "Packaged build/AutoClicker.zip ($(du -h build/AutoClicker.zip | cut -f1))"
