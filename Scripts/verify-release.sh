#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
cd "$repo_root"

readonly expected_branch="release/metalpetal-1.26"
readonly evidence_file="$repo_root/.release-evidence/1.26.0-local.md"

assert_clean() {
  local status_output
  status_output="$(git status --porcelain=v1 --untracked-files=all)"
  if [[ -n "$status_output" ]]; then
    printf 'Release verification requires a clean worktree:\n%s\n' "$status_output" >&2
    return 1
  fi
  printf 'Worktree is clean, including untracked files.\n'
}

run() {
  local command_status
  {
    printf '\n```console\n$'
    printf ' %q' "$@"
    printf '\n'
  } | tee -a "$evidence_file"
  set +e
  "$@" 2>&1 | tee -a "$evidence_file"
  command_status=${PIPESTATUS[0]}
  set -e
  printf '```\n' | tee -a "$evidence_file"
  return "$command_status"
}

run_generators() {
  run swift run --package-path Utilities main boilerplate-generator "$repo_root"
  run swift run --package-path Utilities main umbrella-header-generator "$repo_root"
  run swift run --package-path Utilities main swift-package-generator "$repo_root"
}

assert_no_removed_package_paths() {
  local matches
  local scan_status
  set +e
  matches="$(git ls-files | rg -n '(^|/)(Podfile|Podfile\.lock)$|(^|/)Pods/|\.podspec(\.json)?$|(^|/)(cocoapods|cocoapods-lint)\.yml$|CocoaPodsBundledResourcePlaceholder')"
  scan_status=$?
  set -e
  case "$scan_status" in
    0)
      printf 'Removed package-boundary files remain tracked:\n%s\n' "$matches" >&2
      return 1
      ;;
    1)
      printf 'No removed package-boundary paths are tracked.\n'
      ;;
    *)
      printf 'Package-boundary scan failed with status %s.\n' "$scan_status" >&2
      return "$scan_status"
      ;;
  esac
}

scan_required_reason_apis() {
  local pattern
  local matches
  local scan_status
  pattern='\b(NSUserDefaults|UserDefaults|standardUserDefaults|NSFileCreationDate|NSFileModificationDate|fileCreationDate|fileModificationDate|creationDate(Key)?|modificationDate|contentModificationDate(Key)?|attributeModificationDate(Key)?|NSURLCreationDateKey|NSURLContentModificationDateKey|getattrlist|getattrlistbulk|fgetattrlist|getattrlistat|stat|fstat|fstatat|lstat|volumeAvailableCapacity|volumeAvailableCapacityKey|volumeAvailableCapacityForImportantUsage|volumeAvailableCapacityForImportantUsageKey|volumeAvailableCapacityForOpportunisticUsage|volumeAvailableCapacityForOpportunisticUsageKey|volumeTotalCapacity|volumeTotalCapacityKey|NSURLVolumeAvailableCapacityKey|NSURLVolumeAvailableCapacityForImportantUsageKey|NSURLVolumeAvailableCapacityForOpportunisticUsageKey|NSURLVolumeTotalCapacityKey|systemFreeSize|systemSize|NSFileSystemFreeSize|NSFileSystemSize|f_bfree|f_bavail|statfs|fstatfs|statvfs|fstatvfs|systemUptime|mach_absolute_time|activeInputModes)\b'
  set +e
  matches="$(rg -n -i --glob '*.{h,m,mm,swift,c,cc,cpp}' -e "$pattern" Frameworks/MetalPetal Sources/MetalPetal Sources/MetalPetalObjectiveC 2>&1)"
  scan_status=$?
  set -e
  case "$scan_status" in
    0)
      printf 'Required-reason API candidates require an explicit reviewed privacy-manifest decision:\n%s\n' "$matches" >&2
      return 1
      ;;
    1)
      printf 'No required-reason API candidates matched in Frameworks/MetalPetal, Sources/MetalPetal, or Sources/MetalPetalObjectiveC. This is a limited source scan, not a universal privacy-compliance claim.\n'
      ;;
    *)
      printf 'Required-reason API scan failed with status %s:\n%s\n' "$scan_status" "$matches" >&2
      return "$scan_status"
      ;;
  esac
}

branch="$(git branch --show-current)"
if [[ "$branch" != "$expected_branch" ]]; then
  printf 'Release verification requires branch %s; current branch is %s.\n' "$expected_branch" "${branch:-DETACHED}" >&2
  exit 1
fi

assert_clean
git diff --check

mkdir -p "$(dirname -- "$evidence_file")"
: > "$evidence_file"

metal_path="$(xcrun --find metal)" || {
  printf 'Unable to locate the Metal compiler with xcrun --find metal.\n' >&2
  exit 1
}

{
  printf '# MetalPetal 1.26.0 local release evidence\n\n'
  printf -- '- UTC start: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Commit: `%s`\n' "$(git rev-parse HEAD)"
  printf -- '- Branch: `%s`\n' "$branch"
  printf -- '- Metal compiler: `%s`\n' "$metal_path"
} >> "$evidence_file"

run xcodebuild -version
run swift --version
run "$metal_path" --version

cat >> "$evidence_file" <<'EVIDENCE'

## Known macOS example boundary

The converted macOS example remains in-tree but is not a release gate because its pinned VideoIO 2.0.3 dependency fails under Xcode 26 at `Camera.swift:383-384`, where it declares a stored property unavailable on macOS. The iOS example plus all three clean downstream consumers remain gates.

## Release notes

EVIDENCE
cat RELEASE_NOTES_1.26.0.md >> "$evidence_file"

run_generators
run git diff --check
run assert_clean

run_generators
run git diff --check
run assert_clean

run swift build
run swift test
run bash test.sh
run bash Scripts/test-integration.sh

run assert_no_removed_package_paths
run scan_required_reason_apis

run git diff --check
run assert_clean

printf '\nRelease verification completed successfully at %s UTC.\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" | tee -a "$evidence_file"
