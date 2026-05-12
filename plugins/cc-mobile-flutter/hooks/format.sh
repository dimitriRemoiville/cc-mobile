#!/usr/bin/env bash
# .claude/hooks/format.sh — PostToolUse formatter for Dart.
# Runs `dart format` on the file Claude just edited or wrote. Best-effort:
# never fails the tool call.

set -euo pipefail

FILE="${CLAUDE_FILE_PATHS:-}"

case "$FILE" in
  *.dart) ;;
  *) exit 0 ;;
esac

if command -v dart >/dev/null 2>&1; then
  dart format "$FILE" >/dev/null 2>&1 || true
else
  echo "dart format: skipped (not installed)"
fi
