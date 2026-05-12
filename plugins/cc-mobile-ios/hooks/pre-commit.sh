#!/usr/bin/env bash
# .claude/hooks/pre-commit.sh — PreToolUse gate that blocks `git commit` when
# SwiftLint fails or `swift build` fails on a Swift Package. Skips itself
# when the repo doesn't look like an iOS project (no Package.swift, no
# .xcodeproj, no .xcworkspace at the repo root).
#
# Uses `set -o pipefail` so `swift build 2>&1 | tail -20` propagates the
# real exit code — the previous inline form silently exited 0 because tail
# always succeeds.

set -euo pipefail
set -o pipefail

CMD="${CLAUDE_TOOL_INPUT_command:-}"

case "$CMD" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

if [ ! -f Package.swift ] && ! ls *.xcodeproj >/dev/null 2>&1 && ! ls *.xcworkspace >/dev/null 2>&1; then
  echo "no Package.swift / .xcodeproj / .xcworkspace at repo root (likely a KMM repo); skipping ios pre-commit"
  exit 0
fi

if command -v swiftlint >/dev/null 2>&1; then
  if ! swiftlint --quiet --strict; then
    echo "swiftlint failed; commit blocked"
    exit 1
  fi
else
  echo "swiftlint: skipped (not installed)"
fi

# `swift build` only makes sense on SPM-shaped projects. Skip the xcodebuild
# variant from a commit hook — it's too slow and CI is the right place for it.
if [ -f Package.swift ]; then
  if ! swift build 2>&1 | tail -20; then
    echo "swift build failed; commit blocked"
    exit 1
  fi
fi
