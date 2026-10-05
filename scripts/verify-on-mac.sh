#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-ipa.sh > build.log 2>&1
DEVICE="${SIMULATOR_ID:-$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for k,v in d["devices"].items() if "iOS" in k for x in v if "iPhone" in x["name"]))')}"
xcodebuild -project ios/QMIntake.xcodeproj -scheme QMIntake -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -derivedDataPath build/tests CODE_SIGNING_ALLOWED=NO test > test.log 2>&1
echo 'Device IPA and simulator tests succeeded.'
