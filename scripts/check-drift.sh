#!/usr/bin/env bash
# scripts/check-drift.sh
#
# Surface structural drift across the four stacks (android, ios, kmm, flutter).
#
# What this checks:
#   - Agents: every stack should ship the same set of *logical roles* (reviewer,
#     architect, tester, ...). Missing roles in some stacks are flagged.
#   - Commands: a command present in N-1 stacks but missing from the Nth is
#     flagged. Commands that diverge by design (add-screen vs add-view etc.)
#     are allowlisted in KNOWN_DIVERGENT_COMMANDS.
#   - Skills: stack-prefixed skills (android-testing, ios-testing, ...) should
#     have a counterpart in every stack. Bare skills are single-stack and
#     not checked for parity.
#   - Agent frontmatter shape: every agent should declare the same set of
#     top-level keys. Drift here is how `model: opus` ends up on one reviewer
#     and not the others.
#
# This script does NOT diff prose content — that would create endless noise.
# It only flags structural asymmetry. Compatible with bash 3.2 (macOS default).
#
# Exit 0 on clean. Exit 1 on hard drift.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

STACKS="android ios kmm flutter"
ERRORS=0
WARN=0

red()   { printf "\033[31m%s\033[0m" "$1"; }
green() { printf "\033[32m%s\033[0m" "$1"; }
yellow(){ printf "\033[33m%s\033[0m" "$1"; }
bold()  { printf "\033[1m%s\033[0m" "$1"; }

fail()  { red "  [DRIFT] "; echo "$1"; ERRORS=$((ERRORS + 1)); }
warn()  { yellow "  [warn]  "; echo "$1"; WARN=$((WARN + 1)); }
ok()    { green "  [ ok ]  "; echo "$1"; }

# Strip the stack prefix from a name. Returns the logical role/topic.
# Bare names (no recognized prefix) are returned unchanged.
strip_prefix() {
  local name="$1"
  for s in $STACKS; do
    if [[ "$name" == "$s-"* ]]; then
      printf '%s' "${name#"$s-"}"
      return
    fi
  done
  printf '%s' "$name"
}

has_prefix() {
  local name="$1"
  for s in $STACKS; do
    if [[ "$name" == "$s-"* ]]; then return 0; fi
  done
  return 1
}

# normalize_agent_role: KMM intentionally uses `engineer` instead of
# `ui-engineer` for its non-UI shared-module agent. Treat them as the same
# logical role for parity purposes.
normalize_agent_role() {
  case "$1" in
    engineer) echo "ui-engineer" ;;
    *) echo "$1" ;;
  esac
}

# Collect "stack role" pairs to a temp file, group by role, then report any
# role that doesn't show up in all four stacks.
check_parity() {
  local label="$1" pairs_file="$2" allowlist="${3:-}"
  local roles_file
  roles_file="$(mktemp)"
  awk '{print $2}' "$pairs_file" | sort -u > "$roles_file"

  local any_missing=0
  while IFS= read -r role; do
    [[ -z "$role" ]] && continue
    local stacks_with
    stacks_with="$(awk -v r="$role" '$2 == r {print $1}' "$pairs_file" | sort -u | tr '\n' ' ')"
    local missing=""
    for s in $STACKS; do
      case " $stacks_with " in
        *" $s "*) ;;
        *) missing="$missing $s" ;;
      esac
    done
    if [[ -n "$missing" ]]; then
      missing="${missing# }"
      case " $allowlist " in
        *" $role "*) continue ;;
      esac
      if is_intentional_gap "$role" "$missing"; then continue; fi
      # Count how many stacks have it. Drift only if >=2 have it (otherwise
      # it's a deliberately single-stack item).
      local count
      count="$(echo "$stacks_with" | wc -w | tr -d ' ')"
      if [[ $count -ge 2 ]]; then
        fail "$label '$role' missing in: $missing (present in: ${stacks_with% })"
        any_missing=1
      else
        warn "$label '$role' only in: ${stacks_with% }"
      fi
    fi
  done < "$roles_file"
  rm -f "$roles_file"
  if [[ $any_missing -eq 0 ]]; then
    ok "all $label parallels present in every stack (or allowlisted)"
  fi
}

# ---- Agents -----------------------------------------------------------------

check_agents() {
  bold "agents — logical role parity"; echo
  local pairs
  pairs="$(mktemp)"
  for stack in $STACKS; do
    local dir="$stack/.claude/agents"
    [[ -d "$dir" ]] || { warn "$stack: no agents dir"; continue; }
    for f in "$dir"/*.md; do
      [[ -f "$f" ]] || continue
      local base role
      base="$(basename "$f" .md)"
      if ! has_prefix "$base"; then
        warn "$stack: agent '$base' lacks stack prefix (convention: '${stack}-<role>')"
        continue
      fi
      role="$(normalize_agent_role "$(strip_prefix "$base")")"
      echo "$stack $role" >> "$pairs"
    done
  done
  check_parity "agent role" "$pairs"
  rm -f "$pairs"
  echo
}

# ---- Commands ---------------------------------------------------------------

KNOWN_DIVERGENT_COMMANDS="add-screen add-view add-viewmodel add-bloc"

# Intentional asymmetries — pairs of "<topic>:<missing-stack>". These are
# topics that genuinely don't apply to a given stack and shouldn't be flagged.
# KMM ships no UI, so a11y-reviewer + accessibility skill don't apply at the
# shared layer (the native plugins cover them). Security in KMM is fully
# covered by ktor-multiplatform + multiplatform-settings without a dedicated
# pack.
INTENTIONAL_GAPS="\
a11y-reviewer:kmm \
accessibility:kmm \
security:kmm \
"

# Returns 0 if the (topic, single-missing-stack) pair is allowlisted.
is_intentional_gap() {
  local topic="$1" missing_list="$2"
  # Only honor the allowlist when there's exactly one missing stack — if N>1
  # are missing, it's drift, not a deliberate single-stack exception.
  local count
  count="$(echo "$missing_list" | wc -w | tr -d ' ')"
  [[ "$count" -eq 1 ]] || return 1
  local stack="${missing_list// /}"
  case " $INTENTIONAL_GAPS " in
    *" $topic:$stack "*) return 0 ;;
  esac
  return 1
}

# A command is "inherently per-stack" when its name embeds the stack itself
# (e.g. init-android-app, review-flutter). These never need a parallel.
is_stack_specific_command() {
  local name="$1"
  for s in $STACKS; do
    case "$name" in
      *"-$s"|*"-$s-"*|"$s-"*) return 0 ;;
    esac
  done
  return 1
}

check_commands() {
  bold "commands — cross-stack presence"; echo
  local pairs
  pairs="$(mktemp)"
  for stack in $STACKS; do
    local dir="$stack/.claude/commands"
    [[ -d "$dir" ]] || { warn "$stack: no commands dir"; continue; }
    for f in "$dir"/*.md; do
      [[ -f "$f" ]] || continue
      local base="$(basename "$f" .md)"
      if is_stack_specific_command "$base"; then continue; fi
      echo "$stack $base" >> "$pairs"
    done
  done
  check_parity "command" "$pairs" "$KNOWN_DIVERGENT_COMMANDS"
  rm -f "$pairs"
  echo
}

# ---- Skills (prefixed only) -------------------------------------------------

check_skills() {
  bold "skills — prefixed-topic parity"; echo
  local pairs
  pairs="$(mktemp)"
  for stack in $STACKS; do
    local dir="$stack/.claude/skills"
    [[ -d "$dir" ]] || { warn "$stack: no skills dir"; continue; }
    for skill_dir in "$dir"/*/; do
      [[ -d "$skill_dir" ]] || continue
      local name topic
      name="$(basename "$skill_dir")"
      if ! has_prefix "$name"; then continue; fi
      topic="$(strip_prefix "$name")"
      echo "$stack $topic" >> "$pairs"
    done
  done
  check_parity "skill topic" "$pairs"
  rm -f "$pairs"
  echo
}

# ---- Agent frontmatter key parity ------------------------------------------

REQUIRED_AGENT_KEYS="name description tools skills model"

check_agent_frontmatter() {
  bold "agents — frontmatter key parity"; echo
  local any=0
  for stack in $STACKS; do
    local dir="$stack/.claude/agents"
    [[ -d "$dir" ]] || continue
    for f in "$dir"/*.md; do
      [[ -f "$f" ]] || continue
      local fm missing=""
      fm="$(awk 'BEGIN{c=0} /^---[[:space:]]*$/{c++; next} c==1{print} c==2{exit}' "$f")"
      for key in $REQUIRED_AGENT_KEYS; do
        if ! echo "$fm" | grep -qE "^${key}:"; then
          missing="$missing $key"
        fi
      done
      if [[ -n "$missing" ]]; then
        fail "$stack/$(basename "$f"): missing frontmatter keys:$missing"
        any=1
      fi
    done
  done
  if [[ $any -eq 0 ]]; then ok "every agent declares the required frontmatter keys"; fi
  echo
}

# ---- main -------------------------------------------------------------------

bold "check-drift.sh — cross-stack structural parity"; echo
echo

check_agents
check_commands
check_skills
check_agent_frontmatter

bold "summary"; echo
echo "  drift errors: $ERRORS"
echo "  warnings:     $WARN"

if [[ $ERRORS -gt 0 ]]; then
  echo
  echo "If a flagged asymmetry is intentional, either:"
  echo "  - add the missing counterpart to bring it into line, or"
  echo "  - extend the script's allowlist (KNOWN_DIVERGENT_COMMANDS, etc.)"
  exit 1
fi
exit 0
