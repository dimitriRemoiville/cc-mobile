#!/usr/bin/env bash
# .claude/hooks/pre-commit.sh — PreToolUse gate that blocks `git commit` when
# Android lint or unit tests fail.
#
# Hook contract: Claude Code passes the tool input as JSON on stdin
# ({"tool_name": "Bash", "tool_input": {"command": "..."}}). The legacy
# CLAUDE_TOOL_INPUT_command env var is honored as a fallback so the gate keeps
# working on older versions, but stdin is authoritative on modern Claude Code
# releases — and is the only thing the JSON-based hook spec actually populates.
#
# Skips itself when:
#  - the command isn't a `git commit`,
#  - the repo doesn't look like a single-stack Android project (e.g. KMM where
#    the kmm pre-commit hook is the right one to run),
#  - no Kotlin / Gradle / Android-resource files are staged.

set -euo pipefail

read_command_from_stdin() {
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
print(ti.get("command", ""))
PY
  else
    printf '%s' "$payload" | grep -oE '"command"\s*:\s*"[^"]*"' | head -n 1 \
      | sed -E 's/.*"command"\s*:\s*"(.*)"/\1/'
  fi
}

CMD="$(read_command_from_stdin)"
CMD="${CMD:-${CLAUDE_TOOL_INPUT_command:-}}"

case "$CMD" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

if [ ! -x ./gradlew ]; then
  echo "gradle wrapper missing; skipping pre-commit lint"
  exit 0
fi

# Only run when an :app module is declared at the repo root. KMM repos
# declare :androidApp instead — let the kmm hook handle those.
if ! grep -qE 'include[^A-Za-z]+["'\'']:app["'\'']' settings.gradle settings.gradle.kts 2>/dev/null; then
  echo "no :app module here (likely a KMM/multi-module repo); skipping android pre-commit"
  exit 0
fi

# Only pay the lint+test cost when Kotlin / Gradle / Android resource files are
# actually staged. Touch-only commits to docs/CI shouldn't gate on a 30s+ Gradle
# run.
STAGED="$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)"
if [ -z "$STAGED" ] || ! printf '%s\n' "$STAGED" | grep -qE '\.(kt|kts|gradle|xml|toml|pro)$|^app/src/.+/res/'; then
  echo "no kotlin/gradle/android-resource files staged; skipping android pre-commit"
  exit 0
fi

if ! ./gradlew -q :app:lintDebug :app:testDebugUnitTest; then
  echo "lint/tests failed; commit blocked"
  exit 1
fi
