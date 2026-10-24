#!/bin/bash
# Builds Storyteller.app next to this script.
set -euo pipefail
cd "$(dirname "$0")"

# UNIVERSAL=1 builds for Apple silicon and Intel (used by release.sh).
if [ "${UNIVERSAL:-0}" = 1 ]; then
  swift build -c release --arch arm64 --arch x86_64
  BIN_DIR=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
else
  swift build -c release
  BIN_DIR=$(swift build -c release --show-bin-path)
fi
BIN=$BIN_DIR/Storyteller
VERSION=${VERSION:-1.0.0}
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo 1)

APP=Storyteller.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/"
# Sparkle (auto-updates). The XPC services are only needed by sandboxed apps.
ditto "$BIN_DIR/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
rm -rf "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" "$APP/Contents/Frameworks/Sparkle.framework/XPCServices"

# App icon: Resources/AppIcon.png (from tools/make-icon.swift) -> .icns
ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Storyteller</string>
  <key>CFBundleDisplayName</key><string>Storyteller</string>
  <key>CFBundleExecutable</key><string>Storyteller</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>io.github.naimy441.storyteller</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.entertainment</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>SUFeedURL</key><string>https://github.com/Naimy441/storyteller/releases/latest/download/appcast.xml</string>
  <key>SUPublicEDKey</key><string>w/3k5/K0YCnpKlSFUaM6jvowZokEao5eUnaEeBHC8qc=</string>
  <key>SUEnableAutomaticChecks</key><true/>
  <key>NSAppTransportSecurity</key>
  <dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict>
</plist>
EOF
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
# Make Finder/Dock notice the new icon.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" >/dev/null 2>&1 || true
echo "Built $(pwd)/$APP"
