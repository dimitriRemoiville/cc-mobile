#!/usr/bin/env bash
# .claude/hooks/pre-commit.sh — PreToolUse gate that blocks `git commit` when
# SwiftLint fails or, on SPM-shaped projects, when `swift build` / `swift test`
# fails.
#
# Hook contract: Claude Code passes the tool input as JSON on stdin
# ({"tool_name": "Bash", "tool_input": {"command": "..."}}). The legacy
# CLAUDE_TOOL_INPUT_command env var is honored as a fallback so the gate keeps
# working on older versions, but stdin is authoritative on modern Claude Code
# releases — and is the only thing the JSON-based hook spec actually populates.
#
# Skips itself when:
#  - the command isn't a `git commit`,
#  - the repo doesn't look like an iOS project (no Package.swift / .xcodeproj
#    / .xcworkspace at the repo root — KMM / Android / Flutter repos shouldn't
#    trigger),
#  - no Swift / xcconfig / plist / project files are staged (touch-only docs
#    commits shouldn't pay the xcodebuild cost).
#
# Uses `set -o pipefail` so `swift build 2>&1 | tail -20` propagates the
# real exit code — without it, tail always succeeds and the gate silently
# passes broken builds.

set -euo pipefail
set -o pipefail

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

# Repo-shape check: must be an iOS-flavored repo. KMM and Android repos
# have their own hooks; don't run ours there.
if [ ! -f Package.swift ] && ! ls *.xcodeproj >/dev/null 2>&1 && ! ls *.xcworkspace >/dev/null 2>&1; then
  echo "no Package.swift / .xcodeproj / .xcworkspace at repo root (likely a non-iOS repo); skipping ios pre-commit"
  exit 0
fi

# Staged-file gate: only pay the lint+build cost when iOS-shaped files are
# actually staged. Touch-only commits to docs/CI shouldn't gate on a 30s+
# xcodebuild / swift build run.
STAGED="$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)"
if [ -z "$STAGED" ] || ! printf '%s\n' "$STAGED" | grep -qE '\.(swift|plist|xcconfig)$|/project\.pbxproj$|^Package\.(swift|resolved)$'; then
  echo "no swift/plist/xcconfig/project files staged; skipping ios pre-commit"
  exit 0
fi

if command -v swiftlint >/dev/null 2>&1; then
  if ! swiftlint --quiet --strict; then
    echo "swiftlint failed; commit blocked"
    exit 1
  fi
else
  echo "swiftlint: skipped (not installed)"
fi

# Test gate. xcodebuild from a hook is too brittle (scheme discovery,
# simulator boot, signing prompts), so we prefer cheap, deterministic
# entry points:
#   1. A Makefile `test` target — the project has declared its own runner.
#   2. `swift test` if Package.swift is the root — SPM-shaped projects.
#   3. Otherwise: skip with a one-line note. Don't be a foot-gun.
if [ -f Makefile ] && grep -qE '^test:' Makefile 2>/dev/null; then
  if ! make test 2>&1 | tail -40; then
    echo "make test failed; commit blocked"
    exit 1
  fi
elif [ -f Package.swift ]; then
  if ! swift build 2>&1 | tail -20; then
    echo "swift build failed; commit blocked"
    exit 1
  fi
  if ! swift test 2>&1 | tail -40; then
    echo "swift test failed; commit blocked"
    exit 1
  fi
else
  echo "no test entry point configured for hook (no Makefile \`test\` target, no Package.swift); skipping test gate"
fi
