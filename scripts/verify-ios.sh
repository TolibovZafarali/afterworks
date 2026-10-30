#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
SIMULATOR_ID="${1:-}"
if [[ -z "$SIMULATOR_ID" ]]; then
    echo "Usage: scripts/verify-ios.sh <simulator-udid>"
    echo "Available destinations: xcrun simctl list devices available"
    exit 2
fi

mkdir -p artifacts
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
swift test 2>&1 | tee "artifacts/core-tests-$RUN_STAMP.log"
caffeinate -i xcodebuild test \
    -project Afterworks.xcodeproj \
    -scheme Afterworks \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -parallel-testing-enabled NO \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 180 \
    -maximum-test-execution-time-allowance 600 \
    -derivedDataPath DerivedData \
    -resultBundlePath "artifacts/ui-tests-$RUN_STAMP.xcresult" \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee "artifacts/ui-tests-$RUN_STAMP.log"
