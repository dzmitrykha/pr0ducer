#!/usr/bin/env bash
# Builds the black-box sandbox for the integration tester: compiled Swift
# module artifacts from the PR branch + the task statement, NO sources.
# Runs in the project root; $1 is the issue number.
set -euo pipefail
ISSUE="${1:?usage: prepare-integration-sandbox.sh <issue-number>}"
SANDBOX=".ai-factory/integration/issue-$ISSUE"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PR=$(gh pr list --state open --json number,title,body \
    --jq ".[] | select((.title + .body) | contains(\"#$ISSUE\")) | .number" | head -1)
[ -n "$PR" ] || { echo "no open PR references #$ISSUE" >&2; exit 1; }
BRANCH=$(gh pr view "$PR" --json headRefName --jq .headRefName)

CLONE=$(cd "$(mktemp -d -t factory-it-build)" && pwd -P)
trap 'rm -rf "$CLONE"' EXIT
git clone -q --no-hardlinks . "$CLONE"
git -C "$CLONE" fetch -q origin "$BRANCH"
git -C "$CLONE" switch -qc it-build "origin/$BRANCH" 2>/dev/null \
    || git -C "$CLONE" switch -q "$BRANCH"

swift build -c release --package-path "$CLONE/Packages/ActivityTracker"

BUILD_DIR="$CLONE/Packages/ActivityTracker/.build/release"
MODULE_DIR="$BUILD_DIR/Modules"
rm -rf "$SANDBOX"
mkdir -p "$SANDBOX/lib" "$SANDBOX/docs"
if [ -d "$MODULE_DIR" ]; then
  cp "$MODULE_DIR"/AppFeature.swiftmodule "$MODULE_DIR"/AppFeature.swiftdoc \
     "$SANDBOX/lib/" 2>/dev/null || true
fi
if [ -f "$BUILD_DIR"/libAppFeature.a ]; then
  cp "$BUILD_DIR"/libAppFeature.a "$SANDBOX/lib/"
fi
if [ ! -f "$SANDBOX/lib/AppFeature.swiftmodule" ]; then
  find "$BUILD_DIR" -name 'AppFeature.swiftmodule' -exec cp {} "$SANDBOX/lib/" \;
fi
[ -f "$SANDBOX/lib/AppFeature.swiftmodule" ] \
  || { echo "missing AppFeature.swiftmodule in sandbox" >&2; exit 1; }

gh issue view "$ISSUE" --json title,body \
    --jq '"# " + .title + "\n\n" + .body' > "$SANDBOX/docs/task.md"

echo "sandbox ready: $SANDBOX (PR #$PR, branch $BRANCH)"
