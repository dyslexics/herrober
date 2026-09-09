#!/bin/bash
# H15-Master -> Mac Studio (rsync --delete mit Excludes), danach xcodegen generate.
set -e
rsync -az --delete \
  --exclude build --exclude .git --exclude '*.xcodeproj' --exclude 'Sources/Info.plist' \
  --exclude fastlane/screenshots --exclude fastlane/report.xml --exclude __pycache__ \
  --exclude raw --exclude .venv --exclude tools/review_site/out --exclude tools/downloads --exclude docs/legfragen_'*' \
  /home/mario/herrober-build/ macstudio:herrober/
ssh macstudio 'export PATH=/opt/homebrew/bin:$PATH; cd ~/herrober && xcodegen generate -q && echo "xcodegen OK"'
