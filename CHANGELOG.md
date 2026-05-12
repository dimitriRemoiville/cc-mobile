# Changelog

All notable changes to this repo's Claude Code configurations are logged here. Dates are UTC.

## [Unreleased]

### Added

- Root `CLAUDE.md` and `AGENTS.md` for when the repo root is opened directly (previously the root had only a human-facing `README.md`).
- `.gitignore` at repo root.
- `LICENSE` (MIT).
- `scripts/validate.sh` — parses agent/command frontmatter and resolves relative paths referenced inside commands. Now also enforces that every agent declares a non-empty `skills:` block.
- Per-stack `hooks.json` — `PostToolUse` formatter on `Edit`/`Write`; `PreToolUse` lint gate on `git commit`.
- Per-stack `.claude/hooks/format.sh` and `.claude/hooks/pre-commit.sh` — hook bodies extracted from inline JSON into versioned, syntax-checkable bash scripts. `hooks.json` now references them via `${CLAUDE_PLUGIN_ROOT:-.claude}/hooks/<name>.sh`. `scripts/build-plugin.sh` ships them in the `cc-mobile-*` plugin bundles.
- iOS `init-ios-app` Phase 1.5 — toolchain floor checks (Swift 6, Xcode 16+) plus GitHub Releases-based SPM tag resolution for any third-party packages.
- KMM `init-kmm-app` Phase 1.5 — Maven `maven-metadata.xml` + GitHub Releases version resolution table covering Kotlin, Coroutines, Ktor, Koin, kotlinx.serialization, Compose BOM, SQLDelight, multiplatform-settings, Firebase iOS SDK, plus the Kotlin >= 2.0 floor for K2 idioms.
- New skills:
  - Android: `room-persistence`, `datastore-preferences`, `navigation-compose`, `android-accessibility`, `android-security`, `android-performance`.
  - iOS: `swiftdata-persistence`, `keychain-secure-storage`, `navigation-stack`, `swift-concurrency`, `ios-accessibility`, `ios-security`, `ios-performance`.
  - KMM: `sqldelight-persistence`, `multiplatform-settings`, `kotlinx-serialization`, `xcframework-distribution`.
  - Flutter: `firebase-services`, `localization-arb`, `freezed-patterns`, `openapi-generation`, `flutter-accessibility`, `flutter-security`, `flutter-performance`.
- New agents per stack (security-reviewer, a11y-reviewer, performance-analyst, release-engineer).
- New commands per stack (`/fix-tests`, `/upgrade-deps`, `/add-migration`).
- From-zero scaffolders: `/init-android-app`, `/init-ios-app`, `/init-kmm-app` plus matching `*-app-skeleton` skills.

### Changed

- Agents renamed to stack-prefix convention:
  - `dart-reviewer` -> `flutter-reviewer`
  - `widget-engineer` -> `flutter-ui-engineer`
  - `pub-expert` -> `flutter-build-expert`
  - `kotlin-reviewer` -> `android-reviewer`
  - `compose-ui-engineer` -> `android-ui-engineer`
  - `gradle-expert` -> `android-build-expert`
  - `swift-reviewer` -> `ios-reviewer`
  - `swiftui-engineer` -> `ios-ui-engineer`
  - `spm-expert` -> `ios-build-expert`
  - `shared-module-engineer` -> `kmm-engineer`
  - `gradle-kmp-expert` -> `kmm-build-expert`
- All agent frontmatter normalized: `name`, `description` starting with `Use PROACTIVELY` where applicable, `tools`, `model`. All reviewers bumped to `model: opus`.
- `settings.json` harmonized across four stacks. Single git allow-list and deny-list. `$schema` everywhere. `GRADLE_OPTS` env on Android + KMM.
- iOS deployment target raised to iOS 18 (enables `@Entry` and improved `NavigationStack` ergonomics).
- Android test stack explicitly set to JUnit 4 + MockK + Robolectric (previously ambiguous "JUnit 4/5").
- KMM persistence committed to SQLDelight only (previously "SQLDelight or Room-KMP").
- Compose "40 lines per composable" rule softened to 60-80 with a nesting guideline. The same softened rule now lives consistently in `android/CLAUDE.md`, `android/.claude/agents/android-ui-engineer.md`, and `android/.claude/skills/compose-ui/SKILL.md` (previously the agent + CLAUDE.md still carried the original 40-line text — a documentation drift).
- "Clean architecture" skills renamed to the stack-prefix convention so all four stacks line up: `clean-architecture` → `android-architecture`, `clean-architecture-ios` → `ios-architecture`, `clean-architecture-flutter` → `flutter-architecture`. KMM's `kmm-architecture` was already correct. All agent `skills:` references and command/skill body references updated in lockstep; the `clean-architecture` keyword is preserved in `marketplace.json` and per-plugin `plugin.json` for discoverability.
- `kmm-a11y-reviewer` agent gained a `skills:` block (`kmm-architecture`, `kmm-ios-interop`); previously it was the only agent in the repo without one. `validate.sh` now flags this regression class on every run.
- Flutter `setState` hard-no softened to scope to business/navigation state only.
- `flutter-app-skeleton` split into a core `SKILL.md` plus optional sibling files (`_drift.md`, `_firebase.md`, `_notifications.md`, `_workmanager.md`) loaded conditionally.
- `/init-flutter-app` Phase 0 collapsed from 8 discrete questions to one "confirm or override the defaults" round-trip.
- Per-stack `README.md` files refreshed: `.claude/` ASCII trees now list every shipped agent, skill, and command (previously they showed an outdated 5-of-9 agents / 5-of-13+ skills / 4-of-7+ commands subset), include the new `hooks/` directory, and the slash-command narrative covers the full set (`/init-*-app`, `/upgrade-deps`, `/add-migration`, `/fix-tests`). KMM's and Flutter's READMEs gained a "Specialist agents — quick reference" table to match Android/iOS.
- Per-stack `CLAUDE.md` (Android, iOS, KMM) "Specialist agents" sections now list all nine agents per stack (architect, ui/engineer, reviewer, tester, build-expert, security-reviewer, a11y-reviewer, performance-analyst, release-engineer); "Useful slash commands" sections now cover every shipped command. Flutter's `CLAUDE.md` is convention-only by design and stays unchanged.

### Fixed

- `flutter/.claude/commands/init-flutter-app.md` referenced a leaked sandbox path (`/sessions/wonderful-tender-hawking/mnt/...`) for the skeleton skill. Now references `.claude/skills/flutter-app-skeleton/SKILL.md`.
- `flutter/.claude/commands/init-flutter-app.md` used `$1`; updated to `$ARGUMENTS`.
- iOS pre-commit hook (`ios/.claude/hooks/pre-commit.sh`) — previously the inline form `swift build 2>&1 | tail -20 || { ... }` silently exited 0 on build failure because `tail` always succeeds. Now the body lives in a versioned script with `set -o pipefail` so build failures actually block the commit.
- Stray `.DS_Store` files removed from all four stack folders.
- Android/iOS `settings.json` listed `Read`/`Write`/`Edit`/`Grep`/`Glob` as permissions entries; removed (they are core tools, not Bash patterns).
- Android/iOS `settings.json` did not allow `git commit`/`git add`/`git stash`/`git restore`; added to match Flutter/KMM.
- Removed blanket `git push *` deny on Flutter/KMM (kept `--force` block).
