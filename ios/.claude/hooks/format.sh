#!/usr/bin/env bash
# .claude/hooks/format.sh — PostToolUse formatter for Swift.
#
# Runs a Swift formatter on the file Claude just edited or wrote. Best-effort:
# never fails the tool call. Prefers Apple's `swift-format`, falls back to the
# third-party `swiftformat`; otherwise quietly skips.
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
  *.swift) ;;
  *) exit 0 ;;
esac

if command -v swift-format >/dev/null 2>&1; then
  swift-format format --in-place "$FILE" >/dev/null 2>&1 || true
elif command -v swiftformat >/dev/null 2>&1; then
  swiftformat "$FILE" >/dev/null 2>&1 || true
else
  # Don't fall back to a project-wide `swift-format format -i .`: that
  # reformats the whole tree on every Edit/Write, which is surprising scope
  # creep on a single-file change. Mention it once so the user knows.
  echo "swift-format: skipped ($FILE — install \`swift-format\` or \`swiftformat\` to auto-format on save)"
fi

# swiftlint --fix is intentionally not run here; it's a linter, not a
# formatter, and its --fix changes are noisier than they're worth on a
# per-file save hook. The pre-commit gate runs swiftlint instead.
