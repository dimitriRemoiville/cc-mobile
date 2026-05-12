#!/usr/bin/env bash
# .claude/hooks/format.sh — PostToolUse formatter for KMM.
# Routes Kotlin files to ktlint and Swift files to swiftformat. Best-effort:
# never fails the tool call.

set -euo pipefail

FILE="${CLAUDE_FILE_PATHS:-}"

case "$FILE" in
  *.kt|*.kts)
    if command -v ktlint >/dev/null 2>&1; then
      ktlint -F "$FILE" 2>/dev/null || true
    else
      echo "ktlint: skipped (not installed)"
    fi
    ;;
  *.swift)
    if command -v swiftformat >/dev/null 2>&1; then
      swiftformat "$FILE" >/dev/null 2>&1 || true
    else
      echo "swiftformat: skipped (not installed)"
    fi
    ;;
esac
