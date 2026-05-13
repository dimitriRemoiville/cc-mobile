#!/usr/bin/env bash
# .claude/hooks/pre-commit.sh — PreToolUse gate that blocks `git commit` when
# `:shared:check`, `:androidApp:lintDebug`, or `:androidApp:testDebugUnitTest`
# fail.
#
# Hook contract: Claude Code passes the tool input as JSON on stdin
# ({"tool_name": "Bash", "tool_input": {"command": "..."}}). The legacy
# CLAUDE_TOOL_INPUT_command env var is honored as a fallback so the gate keeps
# working on older versions, but stdin is authoritative on modern Claude Code
# releases — and is the only thing the JSON-based hook spec actually populates.
#
# Skips itself when:
#  - the command isn't a `git commit`,
#  - the repo doesn't look like a KMM project (no `:androidApp` + no shared
#    multiplatform module),
#  - the repo is a single-stack Android repo (`:app` declared instead of
#    `:androidApp`) — the android pre-commit hook handles that shape,
#  - no Kotlin / Gradle / Swift / iOS-config / Android-resource files are
#    staged.
#
# Note: iOS tests are intentionally NOT run here — they require a simulator,
# take minutes, and would push hook latency past the point of usefulness. CI
# (or the release-engineer's pre-release sequence) is where `xcodebuild test`
# runs.

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
  echo "gradle wrapper missing; skipping pre-commit checks"
  exit 0
fi

# Shape check: this hook expects a KMM repo — `:androidApp` plus a shared
# multiplatform module. If only `:app` is declared, it's a single-stack
# Android repo and the android hook should run instead.
if grep -qE 'include[^A-Za-z]+["'\'']:app["'\'']' settings.gradle settings.gradle.kts 2>/dev/null \
   && ! grep -qE 'include[^A-Za-z]+["'\'']:androidApp["'\'']' settings.gradle settings.gradle.kts 2>/dev/null; then
  echo "single-stack android repo (:app, no :androidApp); skipping kmm pre-commit"
  exit 0
fi

if ! grep -qE 'include[^A-Za-z]+["'\'']:androidApp["'\'']' settings.gradle settings.gradle.kts 2>/dev/null; then
  echo "no :androidApp module here (not a KMM repo); skipping kmm pre-commit"
  exit 0
fi

# Require any sign of a Kotlin Multiplatform module — either an explicit
# `:shared` module or a `build.gradle.kts` applying the multiplatform plugin.
if ! grep -qE 'include[^A-Za-z]+["'\'']:shared["'\'']' settings.gradle settings.gradle.kts 2>/dev/null \
   && ! find . -maxdepth 3 -name 'build.gradle.kts' -print0 2>/dev/null \
        | xargs -0 grep -lE 'kotlin\("multiplatform"\)|org\.jetbrains\.kotlin\.multiplatform' \
        >/dev/null 2>&1; then
  echo "no kotlin-multiplatform module detected; skipping kmm pre-commit"
  exit 0
fi

# Only pay the lint+test cost when files that can break Kotlin/Gradle/Swift/
# iOS-config/Android-resource compilation are actually staged. Touch-only
# commits to docs/CI shouldn't gate on a multi-minute Gradle run.
STAGED="$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)"
if [ -z "$STAGED" ] || ! printf '%s\n' "$STAGED" | grep -qE \
  '\.(kt|kts|gradle|toml|pro|swift|plist|xcconfig)$|^iosApp/.+/(Resources|Assets\.xcassets)/|^androidApp/src/.+/res/'; then
  echo "no kotlin/gradle/swift/ios-config/android-resource files staged; skipping kmm pre-commit"
  exit 0
fi

# Run shared checks + Android lint/tests. iOS tests deliberately skipped (see
# header) — let CI cover xcodebuild.
if ! ./gradlew -q :shared:check :androidApp:lintDebug :androidApp:testDebugUnitTest; then
  echo "shared/check, android lint, or android unit tests failed; commit blocked"
  exit 1
fi
