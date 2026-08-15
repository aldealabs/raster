#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
cd "$repo_root"

simulator_udid() {
    local platform="$1"
    xcrun simctl list devices available --json | /usr/bin/jq -r \
        --arg prefix "com.apple.CoreSimulator.SimRuntime.${platform}-" '
        [
          .devices | to_entries[]
          | select(.key | startswith($prefix))
          | .key as $runtime
          | .value[]
          | select(.isAvailable == true)
          | {runtime: $runtime, type: .deviceTypeIdentifier, udid: .udid}
        ]
        | sort_by(.runtime, .type, .udid)
        | reverse
        | .[0].udid // empty
        '
}

scratch_root=""
cleanup() {
    if [[ -n "$scratch_root" && "$scratch_root" == */raster-test.* ]]; then
        rm -rf -- "$scratch_root"
    fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

scratch_root="$(mktemp -d "${TMPDIR:-/tmp}/raster-test.XXXXXX")"
git -C "$repo_root" status --porcelain=v1 -uall > "$scratch_root/status-before"
git -C "$repo_root" diff --binary --no-ext-diff -- > "$scratch_root/diff-before"

echo "------------------"
echo "Preparing generated sources"
echo "------------------"

for pass in 1 2; do
    echo "Generator pass $pass"
    swift run --package-path "$repo_root/Utilities" main boilerplate-generator "$repo_root"
    swift run --package-path "$repo_root/Utilities" main umbrella-header-generator "$repo_root"
    swift run --package-path "$repo_root/Utilities" main swift-package-generator "$repo_root"

    git -C "$repo_root" status --porcelain=v1 -uall > "$scratch_root/status-after-$pass"
    git -C "$repo_root" diff --binary --no-ext-diff -- > "$scratch_root/diff-after-$pass"
    cmp "$scratch_root/status-before" "$scratch_root/status-after-$pass"
    cmp "$scratch_root/diff-before" "$scratch_root/diff-after-$pass"
done

echo "------------------"
echo "Bounded optimizer test (macOS)"
echo "------------------"

xcodebuild test \
    -workspace . \
    -scheme Raster \
    -destination 'platform=macOS' \
    -destination-timeout 30 \
    -parallel-testing-enabled NO \
    -only-testing:RasterTests/RenderTests/testRenderGraphOptimizerCompletesSixtyFourNodeChain \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 5 \
    -maximum-test-execution-time-allowance 5 \
    -collect-test-diagnostics never \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO

echo "------------------"
echo "Smoke Test (macOS)"
echo "------------------"

swift build
swift test

echo "------------------"
echo "Smoke Test (iOS Simulator)"
echo "------------------"

ios_udid="$(simulator_udid iOS)"
if [[ -n "$ios_udid" ]]; then
    echo "Using iOS Simulator: $ios_udid"
    xcodebuild build \
        -workspace . \
        -scheme Raster \
        -destination "platform=iOS Simulator,id=$ios_udid" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO
    xcodebuild test \
        -workspace . \
        -scheme Raster \
        -destination "platform=iOS Simulator,id=$ios_udid" \
        -parallel-testing-enabled NO \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO
else
    echo "Skipping iOS Simulator: no available iOS simulator is installed."
fi

echo "------------------"
echo "Smoke Test (Mac Catalyst)"
echo "------------------"

xcodebuild build \
    -workspace . \
    -scheme Raster \
    -destination 'platform=macOS,variant=Mac Catalyst' \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO
xcodebuild test \
    -workspace . \
    -scheme Raster \
    -destination 'platform=macOS,variant=Mac Catalyst' \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO

echo "------------------"
echo "Smoke Test (tvOS Simulator)"
echo "------------------"

tvos_udid="$(simulator_udid tvOS)"
if [[ -n "$tvos_udid" ]]; then
    echo "Using tvOS Simulator: $tvos_udid"
    xcodebuild build \
        -workspace . \
        -scheme Raster \
        -destination "platform=tvOS Simulator,id=$tvos_udid" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO
    xcodebuild test \
        -workspace . \
        -scheme Raster \
        -destination "platform=tvOS Simulator,id=$tvos_udid" \
        -parallel-testing-enabled NO \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO
else
    echo "Skipping tvOS Simulator: no available tvOS simulator is installed."
fi

echo "------------------"
echo "Build (iOS Device)"
echo "------------------"

xcodebuild build \
    -workspace . \
    -scheme Raster \
    -destination 'generic/platform=iOS' \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO

echo "------------------"
echo "Build (tvOS Device)"
echo "------------------"

if xcodebuild build \
    -workspace . \
    -scheme Raster \
    -destination 'generic/platform=tvOS' \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO 2>&1 | tee "$scratch_root/tvos-device-build.log"; then
    :
else
    tvos_pipeline_status=("${PIPESTATUS[@]}")
    tvos_xcode_status="${tvos_pipeline_status[0]}"
    tvos_tee_status="${tvos_pipeline_status[1]}"
    if (( tvos_tee_status != 0 )); then
        exit "$tvos_tee_status"
    fi
    if /usr/bin/grep -Eq '\{ platform:tvOS, .*name:Any tvOS Device, error:tvOS [0-9]+(\.[0-9]+)* is not installed\.' \
        "$scratch_root/tvos-device-build.log"; then
        tvos_sdk_path="$(xcrun --sdk appletvos --show-sdk-path)"
        echo "Generic tvOS destination is unavailable because the local Xcode tvOS platform component is not installed."
        echo "Running the mandatory tvOS package cross-build with SDK: $tvos_sdk_path"
        swift build \
            --scratch-path "$scratch_root/tvos-cross-build" \
            --triple arm64-apple-tvos13.0 \
            --sdk "$tvos_sdk_path"
    else
        exit "$tvos_xcode_status"
    fi
fi
