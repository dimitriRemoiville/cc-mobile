#!/usr/bin/env bash
# .claude/hooks/pre-commit.sh — PreToolUse gate that blocks `git commit` when
# `:shared:allTests` or `:androidApp:lintDebug` fail. Skips itself when this
# repo doesn't look like a KMM project (no shared module).

set -euo pipefail
set -o pipefail

CMD="${CLAUDE_TOOL_INPUT_command:-}"

case "$CMD" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

if [ ! -x ./gradlew ]; then
  echo "gradle wrapper missing; skipping pre-commit checks"
  exit 0
fi

if ! grep -qE 'include[^A-Za-z]+["'\'']:shared["'\'']' settings.gradle settings.gradle.kts 2>/dev/null; then
  echo "no :shared module here (not a KMM repo); skipping kmm pre-commit"
  exit 0
fi

if ! ./gradlew -q :shared:allTests :androidApp:lintDebug; then
  echo "KMP tests or Android lint failed; commit blocked"
  exit 1
fi
