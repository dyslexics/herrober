#!/bin/bash
# Simulator-Build, Archiv, Export, Upload — in EINER SSH-Session auf dem Mac Studio.
# Aufruf: ssh macstudio 'bash ~/legfragen/tools/mac_release.sh'
set -e
export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
UD=${UD:-380C5D10-5991-4EF6-8676-89F585AAECC8}
PASS=$(cat ~/.secrets/login.pass 2>/dev/null || echo "$LOGIN_PASS")
cd ~/legfragen
xcodegen generate -q
echo "== Simulator-Build"
xcodebuild -scheme LegFragen -destination "platform=iOS Simulator,id=$UD" \
  -derivedDataPath build/dd build -quiet 2>&1 | grep -E "error:|warning: unre" || true
test -d "$(find build/dd/Build/Products -name LegFragen.app -maxdepth 3 | head -1)"
echo "== Archiv"
security unlock-keychain -p "$PASS" login.keychain-db
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASS" login.keychain-db >/dev/null 2>&1 || true
rm -rf build/LegFragen.xcarchive build/export
xcodebuild -scheme LegFragen -destination "generic/platform=iOS" \
  -archivePath build/LegFragen.xcarchive archive -quiet 2>&1 | grep -E "error:|ARCHIVE" || true
test -d build/LegFragen.xcarchive
echo "== Export"
security unlock-keychain -p "$PASS" login.keychain-db
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASS" login.keychain-db >/dev/null 2>&1 || true
xcodebuild -exportArchive -archivePath build/LegFragen.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist 2>&1 | grep -E "error:|EXPORT" || true
ls -la build/export/LegFragen.ipa
/usr/libexec/PlistBuddy -c "Print CFBundleVersion" build/LegFragen.xcarchive/Products/Applications/LegFragen.app/Info.plist
echo "== Upload"
xcrun altool --upload-app -f build/export/LegFragen.ipa -t ios \
  --apiKey V7L56GN3N8 --apiIssuer 69a6de82-3ffb-47e3-e053-5b8c7c11a4d1 2>&1 | grep -iE "UPLOAD|error|Delivery" | head -5
