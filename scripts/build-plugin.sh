#!/usr/bin/env bash
# scripts/build-plugin.sh
#
# Package a stack's .claude/ content for BOTH marketplaces:
#   1. Copilot CLI plugin  — directory with .agent.md agent files
#   2. Claude Code plugin  — .plugin ZIP with .md agent files
#
# Usage:
#   scripts/build-plugin.sh <stack>
#   scripts/build-plugin.sh all
#
# <stack> is one of: android, ios, kmm, flutter.
#
# Layout produced:
#   plugins/cc-mobile-<stack>/
#     .claude-plugin/plugin.json     # authored once, preserved across rebuilds
#     README.md                      # authored once, preserved across rebuilds
#     skills/                        # wiped + refilled from <stack>/.claude/skills
#     agents/                        # wiped + refilled; .agent.md for Copilot CLI
#     commands/                      # wiped + refilled from <stack>/.claude/commands
#     hooks/                         # wiped + refilled from <stack>/.claude/hooks
#     hooks.json                     # copied from <stack>/.claude/hooks.json
#     CLAUDE.md                      # refilled from <stack>/CLAUDE.md
#   plugins/cc-mobile-<stack>.plugin # zip (agents renamed to .md for Claude Code)
#
# The plugin directory uses .agent.md extension for agents (Copilot CLI format).
# The .plugin ZIP renames them to .md (Claude Code format).
# This allows both marketplaces to work from the same repo.
#
# plugin.json is NOT generated here — if missing, the script stops with a clear
# message. Plugin metadata (name, version, description, keywords) should be
# curated per plugin, not auto-written.
#
# Rebuild semantics: the script is safe to re-run. It wipes the dynamic
# directories (skills/, agents/, commands/) and refreshes them, but preserves
# the hand-authored metadata (.claude-plugin/plugin.json, README.md).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

STACKS=(android ios kmm flutter)
PLUGIN_PREFIX="cc-mobile"

red()    { printf "\033[31m%s\033[0m" "$1"; }
green()  { printf "\033[32m%s\033[0m" "$1"; }
yellow() { printf "\033[33m%s\033[0m" "$1"; }
bold()   { printf "\033[1m%s\033[0m" "$1"; }

die()   { red "error: "; echo "$1"; exit 1; }
warn()  { yellow "warn:  "; echo "$1"; }
info()  { green "info:  "; echo "$1"; }

usage() {
  cat >&2 <<USAGE
Usage: $0 <stack|all>

  stack: one of ${STACKS[*]}
  all:   build every stack that has a .claude/ directory

Output:
  plugins/${PLUGIN_PREFIX}-<stack>/           unpacked plugin tree (keep it)
  plugins/${PLUGIN_PREFIX}-<stack>.plugin     installable zip
USAGE
  exit 2
}

build_one() {
  local stack="$1"
  local src="$ROOT/$stack"
  local plugin_name="${PLUGIN_PREFIX}-${stack}"
  local plugin_dir="$ROOT/plugins/$plugin_name"
  local plugin_zip="$ROOT/plugins/${plugin_name}.plugin"
  local manifest="$plugin_dir/.claude-plugin/plugin.json"

  bold "== build $plugin_name =="; echo

  # 1. Source must exist
  [[ -d "$src/.claude" ]] || die "no .claude/ directory under $stack/ — nothing to package"
  [[ -f "$src/CLAUDE.md" ]] || die "no CLAUDE.md under $stack/ — the plugin needs it"

  # 2. Manifest must exist (authored, not generated)
  if [[ ! -f "$manifest" ]]; then
    die "missing manifest: $manifest
  Create it by hand before running this script. Example:
    mkdir -p $(dirname "$manifest")
    cat > $manifest <<JSON
    {
      \"name\": \"$plugin_name\",
      \"version\": \"0.1.0\",
      \"description\": \"Claude Code setup for $stack apps.\",
      \"author\": { \"name\": \"Your Name\" }
    }
JSON"
  fi

  # 3. Plugin README required (authored, not generated)
  if [[ ! -f "$plugin_dir/README.md" ]]; then
    die "missing $plugin_dir/README.md — author it before packaging"
  fi

  # 4. Refresh dynamic content
  info "refreshing skills/ agents/ commands/ hooks/ hooks.json and CLAUDE.md from $stack/"
  rm -rf "$plugin_dir/skills" "$plugin_dir/agents" "$plugin_dir/commands" "$plugin_dir/hooks"

  if [[ -d "$src/.claude/skills" ]]; then
    cp -R "$src/.claude/skills" "$plugin_dir/skills"
  fi
  if [[ -d "$src/.claude/agents" ]]; then
    mkdir -p "$plugin_dir/agents"
    # Copy agents with .agent.md extension (Copilot CLI format).
    # Source files are plain .md; the zip step renames back to .md for Claude Code.
    for agent_src in "$src/.claude/agents/"*.md; do
      [[ -f "$agent_src" ]] || continue
      local base
      base="$(basename "$agent_src" .md)"
      cp "$agent_src" "$plugin_dir/agents/${base}.agent.md"
    done
  fi
  if [[ -d "$src/.claude/commands" ]]; then
    cp -R "$src/.claude/commands" "$plugin_dir/commands"
  fi
  cp "$src/CLAUDE.md" "$plugin_dir/CLAUDE.md"

  # hooks.json + hooks/ scripts ship together. The JSON references
  # ${CLAUDE_PLUGIN_ROOT}/hooks/<name>.sh, which Claude Code substitutes with
  # the unpacked plugin dir at runtime. Without the scripts, the JSON is dead.
  if [[ -f "$src/.claude/hooks.json" ]]; then
    cp "$src/.claude/hooks.json" "$plugin_dir/hooks.json"
  else
    rm -f "$plugin_dir/hooks.json"
  fi
  if [[ -d "$src/.claude/hooks" ]]; then
    cp -R "$src/.claude/hooks" "$plugin_dir/hooks"
    # Preserve executable bits — cp -R on macOS keeps them, but be defensive
    # in case the source tree was checked out without them (Windows / certain
    # tarball extractions).
    find "$plugin_dir/hooks" -name '*.sh' -exec chmod +x {} \;
  fi

  # 4b. Rewrite config-root paths for the plugin runtime.
  #
  # Source files say `.claude/skills/foo/SKILL.md` because a stack folder is
  # also usable by dropping its `.claude/` into a project root (README option
  # C), where that path is literally correct. Once installed as a plugin there
  # is no `.claude/` — the tree lives wherever Claude Code unpacked it, exposed
  # as ${CLAUDE_PLUGIN_ROOT}. Rewriting at package time keeps both modes right
  # from one source.
  #
  # Only the four config subdirectories are rewritten, so prose like "copy
  # `.claude/` into your project" survives untouched. hooks.json is skipped —
  # it already ships the `${CLAUDE_PLUGIN_ROOT:-.claude}` shell form, which
  # resolves correctly in both modes on its own.
  rewrite_plugin_root "$plugin_dir"

  # 5. settings.json is intentionally NOT shipped — it's Claude Code user config,
  #    not plugin config. Surface a warning if someone put one in.
  if [[ -f "$plugin_dir/settings.json" ]]; then
    warn "stray settings.json in plugin dir — removing (plugins use plugin.json, not settings.json)"
    rm -f "$plugin_dir/settings.json"
  fi

  # 6. Strip macOS junk before zipping
  find "$plugin_dir" -name '.DS_Store' -delete 2>/dev/null || true

  # 7. Validate structure
  validate_plugin "$plugin_dir" "$plugin_name"

  # 8. Zip for Claude Code — agents must be .md (not .agent.md) in the archive.
  #    We stage a temp copy with renamed agents, zip that, then clean up.
  local tmp_stage="/tmp/${plugin_name}-stage"
  local tmp_zip="/tmp/${plugin_name}.plugin"
  rm -rf "$tmp_stage" "$tmp_zip"
  cp -R "$plugin_dir" "$tmp_stage"

  # Rename .agent.md → .md inside the staged copy (Claude Code format)
  if [[ -d "$tmp_stage/agents" ]]; then
    for f in "$tmp_stage/agents/"*.agent.md; do
      [[ -f "$f" ]] || continue
      local base
      base="$(basename "$f" .agent.md)"
      mv "$f" "$tmp_stage/agents/${base}.md"
    done
  fi

  (cd "$tmp_stage" && zip -rq "$tmp_zip" . -x '*.DS_Store')
  mkdir -p "$(dirname "$plugin_zip")"
  cp "$tmp_zip" "$plugin_zip"
  rm -rf "$tmp_stage" "$tmp_zip"

  info "wrote $plugin_zip"
  echo
}

rewrite_plugin_root() {
  local plugin_dir="$1"
  local -a targets=()

  for d in skills agents commands; do
    if [[ -d "$plugin_dir/$d" ]]; then targets+=("$plugin_dir/$d"); fi
  done
  if [[ -f "$plugin_dir/CLAUDE.md" ]]; then targets+=("$plugin_dir/CLAUDE.md"); fi
  if [[ ${#targets[@]} -eq 0 ]]; then return 0; fi

  # Anchored on the opening backtick: every such reference in the source tree
  # is written as an inline-code path, so this can't touch prose.
  #
  # Rewrite via a temp file rather than `sed -i`: the in-place flag is not
  # portable. BSD sed (macOS) requires a backup suffix argument, GNU sed (the
  # CI runner) requires the suffix be attached to the flag, and each rejects
  # the other's spelling. Redirecting sidesteps the difference entirely.
  local pattern='`\.claude/(skills|agents|commands|hooks)/'
  local script='s#`\.claude/(skills|agents|commands|hooks)/#`${CLAUDE_PLUGIN_ROOT}/\1/#g'
  local count=0 tmp
  tmp="$(mktemp)"
  while IFS= read -r -d '' f; do
    grep -Eq "$pattern" "$f" || continue
    sed -E "$script" "$f" > "$tmp"
    cat "$tmp" > "$f"   # preserves the original file's mode
    count=$((count + 1))
  done < <(find "${targets[@]}" -type f -name '*.md' -print0)
  rm -f "$tmp"

  info "rewrote .claude/ → \${CLAUDE_PLUGIN_ROOT}/ in $count file(s)"
}

validate_plugin() {
  local plugin_dir="$1" plugin_name="$2"
  local manifest="$plugin_dir/.claude-plugin/plugin.json"

  [[ -f "$manifest" ]] || die "validate: missing manifest"

  # Name in manifest matches directory
  local name_in_json
  name_in_json="$(grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$manifest" | head -n1 | sed -E 's/.*"([^"]+)"$/\1/')"
  [[ "$name_in_json" == "$plugin_name" ]] || \
    die "validate: plugin.json name ($name_in_json) != directory ($plugin_name)"

  # kebab-case
  [[ "$plugin_name" =~ ^[a-z][a-z0-9-]*$ ]] || \
    die "validate: plugin name must be kebab-case"

  # Every skill has SKILL.md
  if [[ -d "$plugin_dir/skills" ]]; then
    while IFS= read -r -d '' skill; do
      [[ -f "$skill/SKILL.md" ]] || die "validate: $skill missing SKILL.md"
    done < <(find "$plugin_dir/skills" -mindepth 1 -maxdepth 1 -type d -print0)
  fi

  # Every agent (.agent.md) and command (.md) file has frontmatter
  if [[ -d "$plugin_dir/agents" ]]; then
    while IFS= read -r -d '' f; do
      head -n1 "$f" | grep -q '^---' || die "validate: $f missing YAML frontmatter"
    done < <(find "$plugin_dir/agents" -mindepth 1 -maxdepth 1 -name '*.agent.md' -print0)
  fi
  if [[ -d "$plugin_dir/commands" ]]; then
    while IFS= read -r -d '' f; do
      head -n1 "$f" | grep -q '^---' || die "validate: $f missing YAML frontmatter"
    done < <(find "$plugin_dir/commands" -mindepth 1 -maxdepth 1 -name '*.md' -print0)
  fi

  info "validated $plugin_name"
}

main() {
  [[ $# -eq 1 ]] || usage
  local target="$1"

  if [[ "$target" == "all" ]]; then
    for s in "${STACKS[@]}"; do
      if [[ -f "$ROOT/plugins/${PLUGIN_PREFIX}-${s}/.claude-plugin/plugin.json" ]]; then
        build_one "$s"
      else
        warn "skipping $s — no plugin scaffold yet (run with '$0 $s' after creating plugins/${PLUGIN_PREFIX}-${s}/)"
      fi
    done
    return
  fi

  local found=0
  for s in "${STACKS[@]}"; do
    [[ "$s" == "$target" ]] && found=1
  done
  [[ $found -eq 1 ]] || die "unknown stack: $target (expected one of: ${STACKS[*]} or 'all')"

  build_one "$target"
}

main "$@"
