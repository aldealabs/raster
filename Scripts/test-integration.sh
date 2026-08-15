#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
scratch_parent="${TMPDIR:-/tmp}"
scratch_root=""

cleanup() {
    if [[ -n "$scratch_root" && "$scratch_root" == */raster-integration.* ]]; then
        rm -rf -- "$scratch_root"
    fi
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

scratch_root="$(mktemp -d "${scratch_parent%/}/raster-integration.XXXXXX")"
git -C "$repo_root" status --porcelain=v1 --untracked-files=all > "$scratch_root/status-before"

echo "Building Swift package consumer"
swift build \
    --package-path "$repo_root/Tests/Integration/SwiftClient" \
    --scratch-path "$scratch_root/swift-client"

echo "Running Swift package consumer"
swift run \
    --skip-build \
    --package-path "$repo_root/Tests/Integration/SwiftClient" \
    --scratch-path "$scratch_root/swift-client" \
    SwiftClient

build_xcode_consumer() {
    local client_name="$1"
    local project_file="$repo_root/Tests/Integration/$client_name/$client_name.xcodeproj"

    echo "Building $client_name"
    xcodebuild \
        -project "$project_file" \
        -scheme "$client_name" \
        -configuration Debug \
        -destination "platform=macOS" \
        -derivedDataPath "$scratch_root/$client_name-derived-data" \
        -clonedSourcePackagesDirPath "$scratch_root/$client_name-source-packages" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY= \
        build
}

build_xcode_consumer ObjCClient
build_xcode_consumer ShaderClient

build_example() {
    local scheme_name="$1"
    local destination_name="$2"
    local derived_name="$3"

    echo "Building $scheme_name"
    xcodebuild \
        -project "$repo_root/RasterExamples.xcodeproj" \
        -scheme "$scheme_name" \
        -configuration Debug \
        -destination "$destination_name" \
        -derivedDataPath "$scratch_root/$derived_name-derived-data" \
        -clonedSourcePackagesDirPath "$scratch_root/example-source-packages" \
        -onlyUsePackageVersionsFromResolvedFile \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY= \
        build
}

if [[ "${RASTER_TEST_MACOS_EXAMPLE:-0}" == 1 ]]; then
    build_example "RasterExamples (macOS)" "platform=macOS" macos-example
else
    echo "Skipping RasterExamples (macOS): pinned VideoIO 2.0.3 fails under Xcode 26 at Camera.swift:383-384."
    echo "Set RASTER_TEST_MACOS_EXAMPLE=1 to retry the normal build without workarounds."
fi
build_example "RasterExamples (iOS)" "generic/platform=iOS" ios-example

git -C "$repo_root" status --porcelain=v1 --untracked-files=all > "$scratch_root/status-after"
if ! cmp -s "$scratch_root/status-before" "$scratch_root/status-after"; then
    echo "Integration builds mutated the source checkout:" >&2
    diff -u "$scratch_root/status-before" "$scratch_root/status-after" >&2 || true
    exit 1
fi

echo "All SwiftPM integration builds passed."
