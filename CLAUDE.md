# ClaudeCodeMobile — mono-config root

This repository is **not** a single project. It's a collection of per-stack Claude Code configurations (Android, iOS, KMM, Flutter). Each subfolder is self-contained and is meant to be opened in isolation (or dropped into the root of an existing project of that stack).

## What to do when Claude opens this folder

1. If the user is working on a specific stack, **open that subfolder** (`android/`, `ios/`, `kmm/`, `flutter/`) and use the stack-local `CLAUDE.md` + `.claude/`. Every stack has its own agents, skills, and slash commands tailored to its conventions.
2. If the user is editing the mono-config itself (adding a new stack, refactoring shared docs, fixing cross-stack typos), stay at the root and consult this file.

## Rules for this repo

- **Do not cross-edit skills between stacks.** A new pattern for Flutter does not get copy-pasted into Android — each stack evolves independently on purpose.
- **Do not introduce a new stack without the full skeleton.** A stack is a folder with `CLAUDE.md`, `README.md`, and `.claude/{settings.json, agents/, skills/, commands/}`. Half-configured stacks create confusion.
- **Use the stack-prefix naming convention for agents.** `android-reviewer`, `ios-reviewer`, `kmm-reviewer`, `flutter-reviewer`, `android-ui-engineer`, `ios-ui-engineer`, etc. No `swift-reviewer` / `kotlin-reviewer` / `dart-reviewer` — those were renamed. KMM's shared-logic counterpart is `kmm-engineer` rather than `kmm-ui-engineer` because the shared module isn't UI.
- **Skill naming — prefix when it's stack-specific behavior; leave bare for language or single-platform frameworks.**
  - Prefix with the stack name when the skill describes how this project *does* something in that stack: `android-testing`, `android-accessibility`, `flutter-bloc`, `flutter-performance`, `kmm-architecture`, `kmm-testing`, `ios-testing`, `ios-security`.
  - Leave bare when the skill's name already scopes it to a language or framework that lives in exactly one stack: `kotlin-style`, `swift-style`, `swift-concurrency`, `compose-ui`, `hilt-di`, `retrofit-networking`, `room-persistence`, `keychain-secure-storage`, `navigation-stack`, `swiftdata-persistence`, `urlsession-networking`, `koin-di`, `ktor-multiplatform`, `sqldelight-persistence`.
  - Cross-stack skills (skills consumed by more than one stack) don't exist by design — if one would be useful, duplicate and adapt per stack.
- **Settings baseline is shared.** The git allow/deny list in every `settings.json` should be identical. Only the toolchain `Bash(...)` allows differ per stack. Stack-specific extra denies (e.g. Flutter's `Bash(flutter upgrade)`, `Bash(fvm install*)`) are allowed but must be obviously scoped to the stack's toolchain.
- **Agents declare their skills explicitly.** Per the [Claude Code subagents spec](https://code.claude.com/docs/en/sub-agents#preload-skills-into-subagents), subagents *do not* inherit skills from the parent conversation — every agent must list the skills it relies on under a `skills:` frontmatter key. Keep the list tight (each listed skill is injected fully into the agent's context at startup, so over-listing bloats context and slows the agent). `validate.sh` enforces that every entry resolves to a real skill in the same stack.
- **Root-level content is thin on purpose.** Conventions live per-stack. The root `README.md` is the orientation map.

## Orientation

See [README.md](README.md) for the cross-stack conventions table and stack layout. See [CHANGELOG.md](CHANGELOG.md) for meaningful changes to this repo.

## Validation

Run [scripts/validate.sh](scripts/validate.sh) before committing config changes. It checks agent/command frontmatter, resolves relative paths referenced inside commands, and validates both marketplace manifests (`.claude-plugin/marketplace.json` for Claude Code, `.github/plugin/marketplace.json` for Copilot CLI).

Run [scripts/check-drift.sh](scripts/check-drift.sh) to surface cross-stack structural drift — logical roles, commands, prefixed skill topics, and required agent frontmatter keys that exist in some stacks but are missing from others. The "don't cross-edit between stacks" rule means improvements never auto-propagate; this script makes the gaps visible.

Both run in CI via [.github/workflows/validate.yml](.github/workflows/validate.yml), which also rebuilds every plugin and fails if `plugins/` is out of sync with the source stack folders.

## Dual marketplace

This repo ships plugins for both **Claude Code** and **GitHub Copilot CLI** from the same source. Agent files under `<stack>/.claude/agents/` are plain `.md`; the build script copies them as `.agent.md` in the plugin directory (Copilot CLI format) and as `.md` in the `.plugin` ZIP (Claude Code format). Do not rename the source files.
