#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodebuild >/dev/null || { echo 'Requires macOS and Xcode 26 or newer.'; exit 1; }
command -v xcodegen >/dev/null || { echo 'Install XcodeGen: brew install xcodegen'; exit 1; }
bash scripts/check-swift-source-size.sh
bash scripts/fetch-idevice.sh
xcodegen generate
xcodebuild archive -project Waypoint.xcodeproj -scheme Waypoint \
  -configuration Release -archivePath build/Pinpoint.xcarchive \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
mkdir -p build/package/Payload
ditto build/Pinpoint.xcarchive/Products/Applications/Waypoint.app build/package/Payload/Waypoint.app
ditto -c -k --sequesterRsrc --keepParent build/package/Payload build/Pinpoint-unsigned.ipa
shasum -a 256 build/Pinpoint-unsigned.ipa > build/Pinpoint-unsigned.ipa.sha256
echo 'Created build/Pinpoint-unsigned.ipa. Signing is still required before installation.'
