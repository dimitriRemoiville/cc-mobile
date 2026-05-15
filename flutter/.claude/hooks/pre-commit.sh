#!/usr/bin/env bash
# .claude/hooks/pre-commit.sh — PreToolUse gate that blocks `git commit` when
# `flutter analyze` or `flutter test` fails.
#
# Hook contract: Claude Code passes the tool input as JSON on stdin
# ({"tool_name": "Bash", "tool_input": {"command": "..."}}). The legacy
# CLAUDE_TOOL_INPUT_command env var is honored as a fallback so the gate keeps
# working on older versions, but stdin is authoritative on modern Claude Code
# releases — and is the only thing the JSON-based hook spec actually populates.
#
# Skips itself when:
#  - the command isn't a `git commit`,
#  - the repo doesn't look like a Flutter/Dart project (no pubspec.yaml),
#  - no Dart / pubspec / analysis / native shell files are staged.

set -euo pipefail

# Fast path: this hook fires on every Bash call but only does real work for
# `git commit`. Short-circuit with a cheap substring check before paying the
# JSON-parser cost.
PAYLOAD=""
if [ ! -t 0 ]; then
  PAYLOAD="$(cat || true)"
fi

HAYSTACK="${PAYLOAD}${CLAUDE_TOOL_INPUT_command:-}"
case "$HAYSTACK" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

read_command_from_payload() {
  [ -z "$PAYLOAD" ] && return 0
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY' "$PAYLOAD"
import json, sys
try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)
ti = data.get("tool_input", {}) if isinstance(data, dict) else {}
print(ti.get("command", ""))
PY
  else
    printf '%s' "$PAYLOAD" | grep -oE '"command"\s*:\s*"[^"]*"' | head -n 1 \
      | sed -E 's/.*"command"\s*:\s*"(.*)"/\1/'
  fi
}

CMD="$(read_command_from_payload)"
CMD="${CMD:-${CLAUDE_TOOL_INPUT_command:-}}"

case "$CMD" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Repo-shape check: a pubspec.yaml at the repo root is the minimum signal that
# this hook applies. Dart-only packages (no `flutter:` in dependencies) are
# fine — the `flutter` CLI proxies to `dart pub` for those.
if [ ! -f pubspec.yaml ]; then
  echo "no pubspec.yaml at repo root; skipping flutter pre-commit"
  exit 0
fi

# Only pay the analyze+test cost when files that could actually break analysis
# or tests are staged. Touch-only commits to docs/CI shouldn't gate on a
# 30s+ analyze/test run.
STAGED="$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)"
if [ -z "$STAGED" ] || ! printf '%s\n' "$STAGED" \
    | grep -qE '\.dart$|(^|/)pubspec\.(yaml|lock)$|(^|/)analysis_options\.yaml$|^android/app/build\.gradle(\.kts)?$|^ios/Runner\.xcodeproj/'; then
  echo "no dart/pubspec/analysis/native-shell files staged; skipping flutter pre-commit"
  exit 0
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter: skipped (not installed)"
  exit 0
fi

if ! flutter analyze --no-fatal-infos; then
  echo "flutter analyze failed; commit blocked"
  exit 1
fi

# Scope tests to `test/` by default — `flutter test` with no argument already
# does this, but be explicit so a top-level `integration_test/` suite isn't
# pulled in on every commit. Run integration_test separately on CI.
if ! flutter test test; then
  echo "flutter test failed; commit blocked"
  exit 1
fi
