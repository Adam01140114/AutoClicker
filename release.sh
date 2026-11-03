#!/bin/bash
# Publishes a release: builds the universal app, zips it, and attaches it to a
# GitHub release so install.sh's one-liner can fetch it.
#   ./release.sh            -> tags with today's date
#   ./release.sh v1.1       -> tags v1.1
set -euo pipefail
cd "$(dirname "$0")"

TAG="${1:-v$(date +%Y.%m.%d)}"
./package.sh

NOTES="Universal build — runs on Apple Silicon and Intel, macOS 14 or later.

Install or update on any Mac with one line:

    curl -fsSL https://raw.githubusercontent.com/Adam01140114/AutoClicker/main/install.sh | bash"

if gh release view "$TAG" >/dev/null 2>&1; then
  gh release upload "$TAG" build/AutoClicker.zip --clobber
else
  gh release create "$TAG" build/AutoClicker.zip --title "AutoClicker $TAG" --notes "$NOTES"
fi
echo "Released $TAG"
