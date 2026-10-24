#!/bin/bash
# Builds a universal, Developer ID–signed, notarized and stapled Storyteller DMG.
# Also writes dist/appcast.xml for Sparkle; upload both to the GitHub release.
# Usage: NOTARY_PROFILE=<notarytool keychain profile> ./release.sh 1.0.0
set -euo pipefail
cd "$(dirname "$0")"

VERSION=${1:?usage: ./release.sh <version>}
IDENTITY=${SIGN_IDENTITY:-"Developer ID Application: 3ata LLC (357LV459V2)"}
PROFILE=${NOTARY_PROFILE:?set NOTARY_PROFILE to your notarytool keychain profile}
APP=Storyteller.app
DMG=dist/Storyteller-$VERSION.dmg

notarize() {
  local out
  out=$(xcrun notarytool submit "$1" --keychain-profile "$PROFILE" --wait 2>&1) || { echo "$out"; exit 1; }
  echo "$out" | tail -3
  if ! echo "$out" | grep -q "status: Accepted"; then
    id=$(echo "$out" | awk '/id:/{print $2; exit}')
    xcrun notarytool log "$id" --keychain-profile "$PROFILE" || true
    exit 1
  fi
}

echo "==> Building $VERSION (universal)"
UNIVERSAL=1 VERSION=$VERSION ./build.sh

echo "==> Signing app"
# Sparkle's helpers first (inside out), then the app.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
for item in "$SPARKLE/Versions/B/Autoupdate" "$SPARKLE/Versions/B/Updater.app" "$SPARKLE"; do
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$item"
done
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Notarizing app"
mkdir -p dist
ditto -c -k --keepParent "$APP" dist/app.zip
notarize dist/app.zip
xcrun stapler staple "$APP"
rm dist/app.zip

echo "==> Building DMG"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Storyteller" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

echo "==> Notarizing DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"

echo "==> Appcast"
# Signed with the EdDSA key in your Keychain (created by Sparkle's generate_keys).
SIG=$(.build/artifacts/sparkle/Sparkle/bin/sign_update "$DMG")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP/Contents/Info.plist")
cat > dist/appcast.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Storyteller</title>
    <item>
      <title>Version $VERSION</title>
      <pubDate>$(date -R)</pubDate>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/Naimy441/storyteller/releases/tag/v$VERSION</sparkle:releaseNotesLink>
      <enclosure url="https://github.com/Naimy441/storyteller/releases/download/v$VERSION/Storyteller-$VERSION.dmg" $SIG type="application/octet-stream"/>
    </item>
  </channel>
</rss>
EOF

echo "==> Gatekeeper check"
spctl -a -t exec -vv "$APP"
spctl -a -t open --context context:primary-signature -vv "$DMG"
echo "Done: $(pwd)/$DMG and $(pwd)/dist/appcast.xml"
echo "Publish: gh release create v$VERSION $DMG dist/appcast.xml"
