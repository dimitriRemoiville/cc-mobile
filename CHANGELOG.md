# Changelog

All notable changes to this repo's Claude Code configurations are logged here. Dates are UTC.

## [Unreleased]

### Added

- Root `CLAUDE.md` and `AGENTS.md` for when the repo root is opened directly (previously the root had only a human-facing `README.md`).
- `.gitignore` at repo root.
- `LICENSE` (MIT).
- `scripts/validate.sh` — parses agent/command frontmatter and resolves relative paths referenced inside commands.
- Per-stack `hooks.json` — `PostToolUse` formatter on `Edit`/`Write`; `PreToolUse` lint gate on `git commit`.
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
- Compose "40 lines per composable" rule softened to 60-80 with a nesting guideline.
- Flutter `setState` hard-no softened to scope to business/navigation state only.
- `flutter-app-skeleton` split into a core `SKILL.md` plus optional sibling files (`_drift.md`, `_firebase.md`, `_notifications.md`, `_workmanager.md`) loaded conditionally.
- `/init-flutter-app` Phase 0 collapsed from 8 discrete questions to one "confirm or override the defaults" round-trip.

### Fixed

- `flutter/.claude/commands/init-flutter-app.md` referenced a leaked sandbox path (`/sessions/wonderful-tender-hawking/mnt/...`) for the skeleton skill. Now references `.claude/skills/flutter-app-skeleton/SKILL.md`.
- `flutter/.claude/commands/init-flutter-app.md` used `$1`; updated to `$ARGUMENTS`.
- Stray `.DS_Store` files removed from all four stack folders.
- Android/iOS `settings.json` listed `Read`/`Write`/`Edit`/`Grep`/`Glob` as permissions entries; removed (they are core tools, not Bash patterns).
- Android/iOS `settings.json` did not allow `git commit`/`git add`/`git stash`/`git restore`; added to match Flutter/KMM.
- Removed blanket `git push *` deny on Flutter/KMM (kept `--force` block).
