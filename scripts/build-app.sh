#!/bin/sh
# Builds a universal (Apple silicon + Intel) LiteStats.app and a zip for GitHub Releases.
set -eu

cd "$(dirname "$0")/.."

APP="build/LiteStats.app"

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/LiteStats" "$APP/Contents/MacOS/LiteStats"
cp Resources/Info.plist "$APP/Contents/Info.plist"
strip -x "$APP/Contents/MacOS/LiteStats"

codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"

ditto -c -k --keepParent "$APP" build/LiteStats.zip

echo "Built $APP ($(du -sh "$APP" | cut -f1))"
echo "Archive: build/LiteStats.zip"
