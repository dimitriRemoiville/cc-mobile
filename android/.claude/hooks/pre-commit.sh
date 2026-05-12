#!/usr/bin/env bash
# .claude/hooks/pre-commit.sh — PreToolUse gate that blocks `git commit` when
# Android lint or unit tests fail. Skips itself when the repo doesn't look
# like a single-stack Android project (e.g. a KMM repo where this stack's
# plugin is installed alongside cc-mobile-kmm and cc-mobile-ios).

set -euo pipefail

CMD="${CLAUDE_TOOL_INPUT_command:-}"

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

if ! ./gradlew -q :app:lintDebug :app:testDebugUnitTest; then
  echo "lint/tests failed; commit blocked"
  exit 1
fi
