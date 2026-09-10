#!/usr/bin/env bash
# Signed archive + IPA export after simulator checks. Does not upload or submit.
# Usage on Mac Studio: bash ~/herrober/tools/mac_archive.sh 2
set -euo pipefail
export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
build_number=${1:?Expected build number required}
[[ "$build_number" =~ ^[0-9]+$ ]] || exit 2
cd "$HOME/herrober"
xcodegen generate -q
mkdir -p build
release_dir=$(mktemp -d "$PWD/build/release-${build_number}.XXXXXX")
unlock_signing() {
    local signing_password
    signing_password=$(cat "$HOME/.secrets/mac.pass")
    security unlock-keychain -p "$signing_password" login.keychain-db
    # Preserve existing key permissions; archive/export must succeed with codesign.
}
unlock_signing
xcodebuild -scheme HerrOber -destination 'generic/platform=iOS' \
    -derivedDataPath build/dd-release \
    -archivePath "$release_dir/HerrOber.xcarchive" archive \
    >"$release_dir/archive.log" 2>&1 || { tail -50 "$release_dir/archive.log"; exit 1; }
app="$release_dir/HerrOber.xcarchive/Products/Applications/HerrOber.app"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Info.plist")" == "$build_number" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")" == 'de.dvld.herrober' ]]
codesign --verify --deep --strict "$app"
unlock_signing
xcodebuild -exportArchive -archivePath "$release_dir/HerrOber.xcarchive" \
    -exportPath "$release_dir/export" -exportOptionsPlist ExportOptions.plist \
    >"$release_dir/export.log" 2>&1 || { tail -50 "$release_dir/export.log"; exit 1; }
test -s "$release_dir/export/HerrOber.ipa"
printf '%s\n' "$release_dir" > "build/release-${build_number}-path.txt"
shasum -a 256 "$release_dir/export/HerrOber.ipa"
printf 'Verified and exported build %s: %s\n' "$build_number" "$release_dir/export/HerrOber.ipa"
