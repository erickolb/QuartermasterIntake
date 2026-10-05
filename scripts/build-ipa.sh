#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
WORK="$(mktemp -d "$ROOT/build-ipa.XXXXXX")"
mkdir -p "$ROOT/dist" "$WORK/Payload"
DERIVED_DATA="${DERIVED_DATA_PATH:-$ROOT/build/iphoneos}"
xcodebuild -project ios/QMIntake.xcodeproj -scheme QMIntake \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" build
APP="$WORK/Payload/QMIntake.app"
ditto "$DERIVED_DATA/Build/Products/Release-iphoneos/QMIntake.app" "$APP"
while IFS= read -r -d '' framework; do
  codesign --force --sign - --timestamp=none "$framework"
done < <(find "$APP" -depth \( -name '*.framework' -o -name '*.dylib' \) -print0)
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
(cd "$WORK" && /usr/bin/zip -qry QM-Intake.ipa Payload)
mv "$WORK/QM-Intake.ipa" "$ROOT/dist/QM-Intake.ipa"
shasum -a 256 "$ROOT/dist/QM-Intake.ipa"
echo "Ready for SideStore: $ROOT/dist/QM-Intake.ipa"
