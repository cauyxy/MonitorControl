#!/bin/bash
# Builds MonitorControl.app without Xcode (Command Line Tools only), ad-hoc signed.
#
# ibtool/actool are Xcode-only, so the compiled storyboard, asset catalog and localizations are taken from
# the upstream release whose UI matches this source (UI_RELEASE). Check `git diff $UI_RELEASE -- MonitorControl/UI
# MonitorControl/Assets.xcassets "MonitorControl/View Controllers"` is empty before bumping it.
#
# Output: PersonalBuild/out/MonitorControl.app
set -euo pipefail

UI_RELEASE=v4.4.0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/PersonalBuild/.work"
OUT="$ROOT/PersonalBuild/out"
APP="$OUT/MonitorControl.app"

mkdir -p "$WORK" "$OUT"
cd "$ROOT"

if [ ! -d "$WORK/release/MonitorControl.app" ]; then
  echo "Fetching compiled UI resources from $UI_RELEASE"
  rm -rf "$WORK/release" && mkdir -p "$WORK/release"
  gh release download "$UI_RELEASE" -R MonitorControl/MonitorControl -p '*.dmg' -D "$WORK/release"
  hdiutil attach -nobrowse -readonly -mountpoint "$WORK/release/mnt" "$WORK"/release/*.dmg >/dev/null
  ditto "$WORK/release/mnt/MonitorControl.app" "$WORK/release/MonitorControl.app"
  hdiutil detach "$WORK/release/mnt" >/dev/null
fi
REL="$WORK/release/MonitorControl.app/Contents"

swift build -c release
BIN="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Library"
cp "$BIN/MonitorControl" "$APP/Contents/MacOS/MonitorControl"
ditto "$BIN/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
ditto "$REL/Resources" "$APP/Contents/Resources"
ditto "$REL/Library/LoginItems" "$APP/Contents/Library/LoginItems"
cp "$REL/PkgInfo" "$APP/Contents/PkgInfo"
cp "$REL/Info.plist" "$APP/Contents/Info.plist"

# Keep Sparkle from offering upstream releases over this build.
plutil -replace CFBundleVersion -string 99999 "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$(plutil -extract CFBundleShortVersionString raw "$REL/Info.plist")-personal" "$APP/Contents/Info.plist"
plutil -replace SUEnableAutomaticChecks -bool NO "$APP/Contents/Info.plist"

codesign --force --sign - "$APP/Contents/Library/LoginItems/MonitorControlHelper.app"
codesign --force --deep --sign - "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - --entitlements "$ROOT/MonitorControl/MonitorControl.entitlements" "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"
