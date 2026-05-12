#!/usr/bin/env bash
# .claude/hooks/format.sh — PostToolUse formatter for Kotlin.
# Runs ktlint -F on the file Claude just edited or wrote. Best-effort: never
# fails the tool call. Prefer the local ktlint binary; fall back to the
# Gradle task if the project ships one; otherwise quietly skip.

set -euo pipefail

FILE="${CLAUDE_FILE_PATHS:-}"

case "$FILE" in
  *.kt|*.kts) ;;
  *) exit 0 ;;
esac

if command -v ktlint >/dev/null 2>&1; then
  ktlint -F "$FILE" 2>/dev/null || true
elif [ -x ./gradlew ]; then
  ./gradlew -q ktlintFormat 2>/dev/null || echo "ktlint: skipped (no ktlint binary, Gradle task unavailable)"
else
  echo "ktlint: skipped (not installed)"
fi
