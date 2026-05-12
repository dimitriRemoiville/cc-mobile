#!/usr/bin/env bash
# .claude/hooks/pre-commit.sh — PreToolUse gate that blocks `git commit` when
# `dart analyze` reports any info or warning. Skips itself when the repo
# isn't a Dart/Flutter project (no pubspec.yaml).

set -euo pipefail
set -o pipefail

CMD="${CLAUDE_TOOL_INPUT_command:-}"

case "$CMD" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

if [ ! -f pubspec.yaml ]; then
  echo "no pubspec.yaml at repo root; skipping flutter pre-commit"
  exit 0
fi

if ! command -v dart >/dev/null 2>&1; then
  echo "dart: skipped (not installed)"
  exit 0
fi

if ! dart analyze --fatal-infos --fatal-warnings; then
  echo "dart analyze failed; commit blocked"
  exit 1
fi
