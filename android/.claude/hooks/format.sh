#!/usr/bin/env bash
# .claude/hooks/format.sh — PostToolUse formatter for Kotlin.
#
# Runs ktlint -F on the file Claude just edited or wrote. Best-effort: never
# fails the tool call. Prefer the local ktlint binary; fall back to the
# Gradle task if the project ships one; otherwise quietly skip.
#
# Hook contract: Claude Code passes the tool input as JSON on stdin
# ({"tool_name": "...", "tool_input": {"file_path": "..."}, ...}). The legacy
# CLAUDE_FILE_PATHS env var is honored as a fallback so this script keeps
# working on older versions, but stdin is the authoritative source on modern
# Claude Code releases.

set -euo pipefail

read_file_from_stdin() {
  if [ -t 0 ]; then return 0; fi
  local payload
  payload="$(cat)" || return 0
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY' "$payload"
import json, sys
try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)
ti = data.get("tool_input", {}) if isinstance(data, dict) else {}
print(ti.get("file_path") or ti.get("path") or ti.get("filePath") or "")
PY
  else
    printf '%s' "$payload" | grep -oE '"file_path"\s*:\s*"[^"]+"' | head -n 1 \
      | sed -E 's/.*"file_path"\s*:\s*"([^"]+)"/\1/'
  fi
}

FILE="$(read_file_from_stdin)"
FILE="${FILE:-${CLAUDE_FILE_PATHS:-}}"

case "$FILE" in
  *.kt|*.kts) ;;
  *) exit 0 ;;
esac

if command -v ktlint >/dev/null 2>&1; then
  ktlint -F "$FILE" >/dev/null 2>&1 || true
elif [ -x ./gradlew ]; then
  ./gradlew -q ktlintFormat 2>/dev/null || echo "ktlint: skipped (no ktlint binary, Gradle task unavailable)"
else
  echo "ktlint: skipped (not installed)"
fi
