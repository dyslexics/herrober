#!/bin/bash
# Simulator-Screenshots per Launch-Args (läuft auf dem Mac Studio). Aufruf: ssh macstudio 'bash ~/herrober/tools/sim_shots.sh [neu]'
# Eigenes Device „Shots-herrober“ (nie `booted`, Parallelbetrieb mit anderen Apps).
set -e
export PATH=/opt/homebrew/bin:$PATH
cd ~/herrober
DEV="Shots-herrober"
UDID=$(xcrun simctl list devices | grep "$DEV (" | head -1 | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/')
if [ -z "$UDID" ]; then
  TYPE=$(xcrun simctl list devicetypes | grep -E "iPhone 17 Pro Max|iPhone 16 Pro Max" | head -1 | sed -E 's/.*\((com[^)]+)\).*/\1/')
  RT=$(xcrun simctl list runtimes | grep iOS | tail -1 | sed -E 's/.*(com\.apple\.CoreSimulator\.SimRuntime\.iOS[^ )]+).*/\1/')
  UDID=$(xcrun simctl create "$DEV" "$TYPE" "$RT")
  echo "created $UDID"
fi
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
if [ "$1" != "keinbuild" ]; then
  xcodebuild -scheme HerrOber -destination "id=$UDID" -derivedDataPath build/sim build CODE_SIGNING_ALLOWED=NO > build/sim-build.log 2>&1
  grep -E "error:|BUILD" build/sim-build.log | sort -u
  grep -q "BUILD SUCCEEDED" build/sim-build.log || { echo "Abbruch: Build fehlgeschlagen, keine Screenshots vom alten Stand."; exit 1; }
fi
APP=$(find build/sim/Build/Products -name "HerrOber.app" -maxdepth 2 | head -1)
xcrun simctl install "$UDID" "$APP"
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
mkdir -p ~/ho_shots
shot() { # name, wartezeit, args…
  local name=$1; local wait=$2; shift 2
  xcrun simctl terminate "$UDID" de.dvld.herrober 2>/dev/null || true
  xcrun simctl launch "$UDID" de.dvld.herrober "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "$HOME/ho_shots/$name.png" >/dev/null
  echo "shot $name"
}
shot 01_start 3 -lang de -demoProgress
shot 02_kapitel_alt_vorlesen 9 -lang de -kapitel capitel-07 -alt -vorlesen
shot 03_kapitel_neu 4 -lang de -kapitel capitel-01 -seite 10 -neu
shot 04_tafel 4 -lang de -tafel 10
shot 05_fibel 3 -lang de -screen fibel
shot 06_quiz 3 -lang de -screen quiz -noShuffle
shot 07_tafeln 3 -lang de -tab 1
shot 08_menu 4 -lang de -menu 08_Schneebergfreunde_1898
shot 09_start_en 3 -lang en
shot 10_ueber 3 -lang de -screen ueber
shot 11_lernen 3 -lang de -screen lernen
shot 12_glossar 3 -lang de -screen glossar
shot 13_warum_neu 4 -lang de -screen warum -neu
shot 14_warum_alt 4 -lang de -screen warum -alt
shot 15_bildaufgabe 4 -lang de -screen bildaufgabe
shot 16_leseuebung 4 -lang de -screen leseuebungen
echo "UDID $UDID"
