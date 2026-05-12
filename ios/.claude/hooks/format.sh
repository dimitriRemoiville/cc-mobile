#!/usr/bin/env bash
# .claude/hooks/format.sh — PostToolUse formatter for Swift.
# Runs swiftformat (if installed) and `swiftlint --fix` (if installed) on
# the file Claude just edited or wrote. Best-effort: never fails the tool
# call.

set -euo pipefail

FILE="${CLAUDE_FILE_PATHS:-}"

case "$FILE" in
  *.swift) ;;
  *) exit 0 ;;
esac

if command -v swiftformat >/dev/null 2>&1; then
  swiftformat "$FILE" >/dev/null 2>&1 || true
else
  echo "swiftformat: skipped (not installed)"
fi

if command -v swiftlint >/dev/null 2>&1; then
  swiftlint --fix --quiet "$FILE" 2>/dev/null || true
fi
