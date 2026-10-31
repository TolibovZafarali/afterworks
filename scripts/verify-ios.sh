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
caffeinate -i swift test --configuration release 2>&1 | tee "artifacts/core-tests-$RUN_STAMP.log"
caffeinate -i xcodebuild build-for-testing \
    -project Afterworks.xcodeproj \
    -scheme Afterworks \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -derivedDataPath DerivedData \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee "artifacts/build-tests-$RUN_STAMP.log"

SIMULATOR_SDK_VERSION="$(xcrun --sdk iphonesimulator --show-sdk-version)"
TEST_RUN_FILES=(DerivedData/Build/Products/Afterworks_iphonesimulator"$SIMULATOR_SDK_VERSION"-*.xctestrun)
if [[ ${#TEST_RUN_FILES[@]} -ne 1 || ! -f "${TEST_RUN_FILES[0]}" ]]; then
    echo "Expected one Afterworks test-run file for simulator SDK $SIMULATOR_SDK_VERSION."
    echo "Check DerivedData/Build/Products for missing or ambiguous test-run artifacts."
    exit 3
fi

caffeinate -i xcodebuild test-without-building \
    -xctestrun "${TEST_RUN_FILES[0]}" \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -parallel-testing-enabled NO \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 180 \
    -maximum-test-execution-time-allowance 600 \
    -resultBundlePath "artifacts/ui-tests-$RUN_STAMP.xcresult" \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee "artifacts/ui-tests-$RUN_STAMP.log"
