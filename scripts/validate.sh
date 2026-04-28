#!/usr/bin/env bash
# scripts/validate.sh
# Validate every .md under .claude/agents/ and .claude/commands/ across the four stacks:
#   - frontmatter present
#   - required keys present (name, description for agents; description for commands)
#   - every relative path mentioned inside the markdown resolves on disk
#
# Exit 0 on success. Exit 1 on any validation failure. Prints a grouped report.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

STACKS=(android ios kmm flutter)
ERRORS=0
WARN=0

red()   { printf "\033[31m%s\033[0m" "$1"; }
green() { printf "\033[32m%s\033[0m" "$1"; }
yellow(){ printf "\033[33m%s\033[0m" "$1"; }
bold()  { printf "\033[1m%s\033[0m" "$1"; }

say_err() { red "  [FAIL] "; echo "$1"; ERRORS=$((ERRORS + 1)); }
say_warn(){ yellow "  [WARN] "; echo "$1"; WARN=$((WARN + 1)); }
say_ok()  { green "  [ OK ] "; echo "$1"; }

# ---------- helpers ----------

# Extract frontmatter block (between the first two --- lines) from a file.
# Prints the body only.
extract_frontmatter() {
  awk 'BEGIN{c=0} /^---[[:space:]]*$/{c++; next} c==1{print} c==2{exit}' "$1"
}

# Check a key is present in a frontmatter block. Prints 1 if present, 0 otherwise.
has_key() {
  local fm="$1" key="$2"
  if echo "$fm" | grep -qE "^${key}:"; then echo 1; else echo 0; fi
}

# Extract referenced paths from a markdown body. Strategy: markdown links only,
# and only outside fenced code blocks. This intentionally ignores backticked
# bare filenames, which are typically illustrative ("edit pubspec.yaml") and
# not meant to resolve relative to the doc's location.
extract_paths() {
  awk '
    BEGIN { in_fence = 0 }
    /^```/ { in_fence = 1 - in_fence; next }
    in_fence == 0 {
      line = $0
      while (match(line, /\[[^]]+\]\(([^)]+)\)/)) {
        ref = substr(line, RSTART, RLENGTH)
        sub(/^\[[^]]+\]\(/, "", ref)
        sub(/\).*$/, "", ref)
        print ref
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' "$1" \
    | grep -vE '^(https?:|mailto:|ftp:|#)' \
    | grep -vE '^[{#<]'
}

# Resolve a referenced path against the markdown file's directory *and* the
# workspace root, plus bubble up one level for convenience (so that
# `.claude/skills/foo/SKILL.md` referenced from `{stack}/.claude/commands/`
# resolves under `{stack}/`).
resolve_path() {
  local md_file="$1" ref="$2"
  local md_dir stack_dir candidate

  md_dir="$(cd "$(dirname "$md_file")" && pwd)"

  # strip anchors and placeholders like {{FOO}}
  ref="${ref%%#*}"
  if [[ "$ref" == *"{{"*"}}"* ]]; then
    # skip placeholder paths — they're intentional templates
    return 0
  fi

  # absolute
  if [[ "$ref" == /* ]]; then
    [[ -e "$ref" ]] && return 0 || return 1
  fi

  # relative to markdown file
  candidate="$md_dir/$ref"
  [[ -e "$candidate" ]] && return 0

  # relative to workspace root
  candidate="$ROOT/$ref"
  [[ -e "$candidate" ]] && return 0

  # relative to the stack directory (two levels up from .claude/{agents,commands,skills}/*)
  stack_dir="$(cd "$md_dir/../.." 2>/dev/null && pwd || true)"
  if [[ -n "${stack_dir:-}" ]]; then
    candidate="$stack_dir/$ref"
    [[ -e "$candidate" ]] && return 0
  fi

  return 1
}

validate_agent_file() {
  local f="$1"
  local fm
  fm="$(extract_frontmatter "$f")"
  if [[ -z "$fm" ]]; then
    say_err "$f: missing frontmatter"
    return
  fi
  for key in name description; do
    if [[ "$(has_key "$fm" "$key")" != "1" ]]; then
      say_err "$f: frontmatter missing required key: $key"
    fi
  done
  # optional but recommended
  if [[ "$(has_key "$fm" "model")" != "1" ]]; then
    say_warn "$f: no model: key (defaults apply, but explicit is safer)"
  fi
  if [[ "$(has_key "$fm" "tools")" != "1" ]]; then
    say_warn "$f: no tools: key (review agents should restrict tools)"
  fi
  validate_body_paths "$f"
}

validate_skill_file() {
  local f="$1"
  local fm
  fm="$(extract_frontmatter "$f")"
  if [[ -z "$fm" ]]; then
    say_err "$f: missing frontmatter"
    return
  fi
  for key in name description; do
    if [[ "$(has_key "$fm" "$key")" != "1" ]]; then
      say_err "$f: frontmatter missing required key: $key"
    fi
  done
  validate_body_paths "$f"
}

validate_command_file() {
  local f="$1"
  local fm
  fm="$(extract_frontmatter "$f")"
  if [[ -z "$fm" ]]; then
    say_err "$f: missing frontmatter"
    return
  fi
  for key in description; do
    if [[ "$(has_key "$fm" "$key")" != "1" ]]; then
      say_err "$f: frontmatter missing required key: $key"
    fi
  done
  validate_body_paths "$f"
}

validate_body_paths() {
  local f="$1"
  local broken=0
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    if ! resolve_path "$f" "$ref"; then
      say_err "$f: referenced path does not resolve: $ref"
      broken=$((broken + 1))
    fi
  done < <(extract_paths "$f" | sort -u)
  if [[ $broken -eq 0 ]]; then
    say_ok "$f"
  fi
}

# ---------- cross-stack checks ----------
#
# Baseline entries that every stack's .claude/settings.json MUST carry. Stacks
# may (and do) add toolchain-specific allows and extra scoped denies on top —
# those are inspected but not compared here. The root CLAUDE.md calls this the
# "shared baseline" contract.

BASELINE_ALLOWS=(
  '"Bash(git status*)"'
  '"Bash(git diff*)"'
  '"Bash(git log*)"'
  '"Bash(git branch*)"'
  '"Bash(git show*)"'
  '"Bash(git add*)"'
  '"Bash(git commit*)"'
  '"Bash(git restore*)"'
  '"Bash(git stash*)"'
  '"Bash(ls*)"'
  '"Bash(find*)"'
  '"Bash(tree*)"'
  '"Bash(wc*)"'
)
BASELINE_DENIES=(
  '"Bash(git push --force*)"'
  '"Bash(git reset --hard*)"'
  '"Bash(rm -rf /*)"'
)

# Skill dir names that are allowed to carry a foreign-stack prefix despite
# living under another stack. Empty by default: every exception should be
# argued for explicitly in code review.
SKILL_PREFIX_WHITELIST=()

check_settings_baseline() {
  for stack in "${STACKS[@]}"; do
    local f="$ROOT/$stack/.claude/settings.json"
    if [[ ! -f "$f" ]]; then
      say_err "$stack: missing .claude/settings.json"
      continue
    fi
    local missing=0
    for entry in "${BASELINE_ALLOWS[@]}"; do
      if ! grep -qF "$entry" "$f"; then
        say_err "$stack/.claude/settings.json: missing baseline allow entry: $entry"
        missing=$((missing + 1))
      fi
    done
    for entry in "${BASELINE_DENIES[@]}"; do
      if ! grep -qF "$entry" "$f"; then
        say_err "$stack/.claude/settings.json: missing baseline deny entry: $entry"
        missing=$((missing + 1))
      fi
    done
    if [[ $missing -eq 0 ]]; then
      say_ok "$stack/.claude/settings.json: baseline entries present"
    fi
  done
}

check_plugin_parity() {
  for stack in "${STACKS[@]}"; do
    local plugin_root="$ROOT/plugins/cc-mobile-$stack"
    if [[ ! -d "$plugin_root" ]]; then
      say_warn "plugins/cc-mobile-$stack: directory missing (run scripts/build-plugin.sh)"
      continue
    fi
    local mismatch=0
    local src_dir plug_dir src_names plug_names diff
    for kind in agents commands; do
      src_dir="$ROOT/$stack/.claude/$kind"
      plug_dir="$plugin_root/$kind"
      src_names=$(cd "$src_dir" 2>/dev/null && find . -maxdepth 1 -name '*.md' | xargs -I{} basename {} | sort || true)
      plug_names=$(cd "$plug_dir" 2>/dev/null && find . -maxdepth 1 -name '*.md' | xargs -I{} basename {} | sort || true)
      if [[ "$src_names" != "$plug_names" ]]; then
        diff=$(diff <(echo "$src_names") <(echo "$plug_names") | tr '\n' ' ')
        say_err "plugins/cc-mobile-$stack/$kind: file-set drift vs source (plugin rebuild needed): $diff"
        mismatch=$((mismatch + 1))
      fi
    done
    src_dir="$ROOT/$stack/.claude/skills"
    plug_dir="$plugin_root/skills"
    src_names=$(cd "$src_dir" 2>/dev/null && find . -mindepth 1 -maxdepth 1 -type d | xargs -I{} basename {} | sort || true)
    plug_names=$(cd "$plug_dir" 2>/dev/null && find . -mindepth 1 -maxdepth 1 -type d | xargs -I{} basename {} | sort || true)
    if [[ "$src_names" != "$plug_names" ]]; then
      diff=$(diff <(echo "$src_names") <(echo "$plug_names") | tr '\n' ' ')
      say_err "plugins/cc-mobile-$stack/skills: dir-set drift vs source (plugin rebuild needed): $diff"
      mismatch=$((mismatch + 1))
    fi
    if [[ $mismatch -eq 0 ]]; then
      say_ok "plugins/cc-mobile-$stack: agents/commands/skills match source"
    fi
  done
}

# Flag any skill directory whose name starts with a foreign-stack prefix —
# e.g. `kmm/.claude/skills/ios-interop/`. Per the root CLAUDE.md naming rule,
# stack-prefixed names are reserved for the stack they live under; a foreign
# prefix is either a misplaced skill or a naming bug.
check_skill_prefixes() {
  local all_prefixes="android ios kmm flutter"
  for stack in "${STACKS[@]}"; do
    local skills_dir="$ROOT/$stack/.claude/skills"
    [[ ! -d "$skills_dir" ]] && continue
    local flagged=0
    while IFS= read -r -d '' skill_dir; do
      local name other whitelisted=0
      name="$(basename "$skill_dir")"
      for w in "${SKILL_PREFIX_WHITELIST[@]:-}"; do
        if [[ "$w" == "$stack:$name" ]]; then
          whitelisted=1
          break
        fi
      done
      [[ $whitelisted -eq 1 ]] && continue
      for other in $all_prefixes; do
        [[ "$other" == "$stack" ]] && continue
        if [[ "$name" == "$other"-* ]]; then
          say_err "$stack/.claude/skills/$name: foreign-stack prefix \"$other-\" (rename per root CLAUDE.md naming rule, or whitelist)"
          flagged=$((flagged + 1))
          break
        fi
      done
    done < <(find "$skills_dir" -mindepth 1 -maxdepth 1 -type d -print0)
    if [[ $flagged -eq 0 ]]; then
      say_ok "$stack: skill names respect stack-prefix rule"
    fi
  done
}

# Every stack's agents/ directory should follow the `<stack>-<role>.md`
# convention except for the `*-engineer` / `*-ui-engineer` swap that KMM uses
# deliberately. Flag any agent file whose basename doesn't start with the
# stack prefix.
check_agent_prefixes() {
  for stack in "${STACKS[@]}"; do
    local agents_dir="$ROOT/$stack/.claude/agents"
    [[ ! -d "$agents_dir" ]] && continue
    local flagged=0
    while IFS= read -r -d '' f; do
      local name
      name="$(basename "$f" .md)"
      if [[ "$name" != "$stack"-* ]]; then
        say_err "$stack/.claude/agents/$name.md: agent name missing stack prefix \"$stack-\" (rename per root CLAUDE.md)"
        flagged=$((flagged + 1))
      fi
    done < <(find "$agents_dir" -maxdepth 1 -name '*.md' -print0)
    if [[ $flagged -eq 0 ]]; then
      say_ok "$stack: agent names carry stack prefix"
    fi
  done
}

# Every `skills:` entry in an agent's frontmatter must map to a real skill
# directory under the same stack's .claude/skills/. Catches typos and stale
# references after a skill is renamed or removed.
check_agent_skills_resolve() {
  for stack in "${STACKS[@]}"; do
    local agents_dir="$ROOT/$stack/.claude/agents"
    local skills_dir="$ROOT/$stack/.claude/skills"
    [[ ! -d "$agents_dir" || ! -d "$skills_dir" ]] && continue
    local flagged=0
    while IFS= read -r -d '' f; do
      local fm in_skills=0
      fm="$(extract_frontmatter "$f")"
      while IFS= read -r line; do
        if [[ "$line" =~ ^skills:[[:space:]]*$ ]]; then
          in_skills=1
          continue
        fi
        if [[ $in_skills -eq 1 ]]; then
          if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.+)[[:space:]]*$ ]]; then
            local skill_name="${BASH_REMATCH[1]}"
            skill_name="${skill_name%"${skill_name##*[![:space:]]}"}"  # rtrim
            if [[ ! -d "$skills_dir/$skill_name" ]]; then
              say_err "$stack/.claude/agents/$(basename "$f"): references missing skill: $skill_name"
              flagged=$((flagged + 1))
            fi
          else
            in_skills=0
          fi
        fi
      done <<<"$fm"
    done < <(find "$agents_dir" -maxdepth 1 -name '*.md' -print0)
    if [[ $flagged -eq 0 ]]; then
      say_ok "$stack: agent skills: references resolve to real skills"
    fi
  done
}

# ---------- main ----------

bold "validate.sh — scanning .claude/ content across ${STACKS[*]}"; echo
echo

for stack in "${STACKS[@]}"; do
  bold "== $stack =="; echo
  agents_dir="$ROOT/$stack/.claude/agents"
  commands_dir="$ROOT/$stack/.claude/commands"
  skills_dir="$ROOT/$stack/.claude/skills"

  if [[ -d "$agents_dir" ]]; then
    while IFS= read -r -d '' f; do
      validate_agent_file "$f"
    done < <(find "$agents_dir" -maxdepth 1 -name '*.md' -print0)
  else
    say_warn "$stack: no agents directory"
  fi

  if [[ -d "$commands_dir" ]]; then
    while IFS= read -r -d '' f; do
      validate_command_file "$f"
    done < <(find "$commands_dir" -maxdepth 1 -name '*.md' -print0)
  else
    say_warn "$stack: no commands directory"
  fi

  if [[ -d "$skills_dir" ]]; then
    while IFS= read -r -d '' f; do
      validate_skill_file "$f"
    done < <(find "$skills_dir" -mindepth 2 -maxdepth 2 -name 'SKILL.md' -print0)
  fi
  echo
done

bold "== cross-stack =="; echo
check_settings_baseline
check_plugin_parity
check_skill_prefixes
check_agent_prefixes
check_agent_skills_resolve
echo

bold "summary"; echo
echo "  errors:   $ERRORS"
echo "  warnings: $WARN"

if [[ $ERRORS -gt 0 ]]; then
  exit 1
fi
exit 0
