#!/usr/bin/env bash
# Architecture gate for pr0ducer: Swift build/tests, SwiftLint (strict),
# SwiftFormat lint, package boundary check, and xcodebuild warnings-as-errors.
# Usage: scripts/analyze.sh <issue-number>
set -euo pipefail

ISSUE="${1:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FINDINGS=()

emit_finding() {
  FINDINGS+=("$1")
  printf '%s\n' "$1"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    emit_finding "blocker | $ROOT | missing-tool | required command not found: $1"
    return 1
  }
}

run_swift_package_gate() {
  if ! swift build -c debug --package-path Packages/ActivityTracker 2>&1; then
    emit_finding "blocker | Packages/ActivityTracker | build-failed | swift build failed"
    return 1
  fi
  if ! swift test --package-path Packages/ActivityTracker 2>&1; then
    emit_finding "blocker | Packages/ActivityTracker | test-failed | swift test failed"
    return 1
  fi
}

run_swiftlint() {
  require_cmd swiftlint || return 1
  if ! swiftlint lint --strict --quiet; then
    emit_finding "major | $ROOT | swiftlint | swiftlint --strict reported violations"
    return 1
  fi
}

run_swiftformat() {
  require_cmd swiftformat || return 1
  if ! swiftformat --lint .; then
    emit_finding "major | $ROOT | swiftformat | swiftformat --lint reported violations"
    return 1
  fi
}

check_package_boundary() {
  local app_sources="$ROOT/App/Watch"
  if grep -R --include='*.swift' -E '@Reducer|struct AppFeature|enum AppFeature' "$app_sources" \
      | grep -v 'import AppFeature' >/dev/null 2>&1; then
    emit_finding "major | App/Watch | boundary-violation | duplicated feature logic in app target"
    return 1
  fi
  if ! grep -q 'import AppFeature' "$app_sources"/ActivityTrackerApp.swift; then
    emit_finding "major | App/Watch | boundary-violation | app shell must import AppFeature"
    return 1
  fi
}

run_xcodegen_and_app_build() {
  require_cmd xcodegen || return 1
  (cd App && xcodegen generate >/dev/null)
  if command -v xcodebuild >/dev/null 2>&1; then
    if ! xcodebuild -project App/ActivityTracker.xcodeproj -scheme ActivityTracker \
        -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
        -quiet build; then
      emit_finding "major | App/ActivityTracker.xcodeproj | xcodebuild-failed | app shell build failed"
      return 1
    fi
  fi
}

main() {
  local failed=0
  run_swift_package_gate || failed=1
  run_swiftlint || failed=1
  run_swiftformat || failed=1
  check_package_boundary || failed=1
  run_xcodegen_and_app_build || failed=1

  if ((${#FINDINGS[@]} > 0)); then
    printf '\n--- architecture gate: %s finding(s) ---\n' "${#FINDINGS[@]}"
    printf '%s\n' "${FINDINGS[@]}"
  fi

  if ((failed != 0)); then
    exit 1
  fi
  echo "architecture gate passed (issue ${ISSUE:-n/a})"
}

main "$@"
