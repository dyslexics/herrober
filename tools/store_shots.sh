#!/bin/bash
# Store-Screenshots (iPhone 6.9" + iPad 13") in DE + EN. Eigene Simulator-Geräte, nie "booted".
# Aufruf: ssh macstudio 'bash ~/legfragen/tools/store_shots.sh'
set -e
export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
PHONE=380C5D10-5991-4EF6-8676-89F585AAECC8
IPAD=50B81D17-5DBC-4E17-8750-AFC7FDF1C1B5
BID=de.dvld.legfragen
cd ~/legfragen
APP=$(find build/dd/Build/Products -name "LegFragen.app" -maxdepth 3 | head -1)
test -d "$APP"

prep () {
  UD=$1
  xcrun simctl boot $UD 2>/dev/null || true
  xcrun simctl bootstatus $UD -b >/dev/null 2>&1
  xcrun simctl status_bar $UD override --time "9:41" --batteryLevel 100 --batteryState charged --wifiBars 3 --cellularBars 4 >/dev/null 2>&1 || true
  xcrun simctl uninstall $UD $BID 2>/dev/null || true
  xcrun simctl install $UD "$APP"
}

shot () {
  UD=$1; OUT=$2; name=$3; shift 3
  xcrun simctl terminate $UD $BID 2>/dev/null || true
  xcrun simctl launch $UD $BID "$@" >/dev/null
  sleep 5
  xcrun simctl io $UD screenshot "$OUT/$name.png" >/dev/null 2>&1
  echo "  $OUT/$name  $(md5 -q "$OUT/$name.png")"
}

# Inhalte sind deutsch; EN-Screenshots zeigen die englische Oberfläche mit denselben Kapiteln.
set_all () {
  UD=$1; LOC=$2; L=$3; THEMA=$4; SUFFIX=$5
  OUT=fastlane/screenshots/$LOC; mkdir -p $OUT
  shot $UD $OUT "01_library$SUFFIX"  -lang $L -demoProgress
  shot $UD $OUT "02_chapter$SUFFIX"  -lang $L -demoProgress -screen chapter -thema $THEMA -chapter 1
  shot $UD $OUT "03_quiz$SUFFIX"     -lang $L -screen quiz -thema $THEMA -chapter 1 -demoAnswered
  shot $UD $OUT "04_result$SUFFIX"   -lang $L -screen result -thema $THEMA -chapter 1
  shot $UD $OUT "05_progress$SUFFIX" -lang $L -demoProgress -tab 1
}

prep $PHONE
set_all $PHONE de-DE de grundlagen ""
set_all $PHONE en-US en grundlagen ""
prep $IPAD
sleep 20   # „Apple Intelligence"-Banner abwarten
set_all $IPAD de-DE de grundlagen "_ipad"
set_all $IPAD en-US en grundlagen "_ipad"
xcrun simctl shutdown $IPAD >/dev/null 2>&1 || true
echo "fertig"
