# Changelog

All notable changes to this repo's Claude Code configurations are logged here. Dates are UTC. See `git log` for per-change rationale.

## [Unreleased]

## [0.1.0] — 2026-05-13

First tagged release. Four per-stack configurations (Android, iOS, KMM, Flutter) at rough parity: each ships a from-zero scaffolder, a full agent roster, hooks, and a focused skill library.

### Added

- From-zero scaffolders for every stack: `/init-android-app`, `/init-ios-app`, `/init-kmm-app`, `/init-flutter-app`, each backed by a `*-app-skeleton` skill with online version resolution (Maven `maven-metadata.xml` / GitHub Releases / pub.dev) and toolchain floor checks.
- Full agent roster per stack: architect, ui-engineer (or `kmm-engineer`), reviewer, tester, build-expert, security-reviewer, a11y-reviewer, performance-analyst, release-engineer.
- New commands per stack: `/fix-tests`, `/upgrade-deps`, `/add-migration` (plus Android `/add-screen`, `/add-usecase`, `/new-feature`).
- Per-stack hooks: `PostToolUse` formatter on `Edit`/`Write` and `PreToolUse` lint gate on `git commit`, with bodies in versioned `.claude/hooks/*.sh` scripts (referenced via `${CLAUDE_PLUGIN_ROOT:-.claude}`).
- New skills across stacks covering persistence (Room, SwiftData, SQLDelight, Drift), secure storage, navigation, concurrency, accessibility, security, performance, and platform-specific build patterns.
- `scripts/validate.sh` — frontmatter parser that resolves command paths and enforces a non-empty `skills:` block on every agent.

### Changed

- Agents renamed to stack-prefix convention (`android-reviewer`, `ios-ui-engineer`, `flutter-build-expert`, `kmm-engineer`, etc.). All frontmatter normalized; reviewers use `model: opus`.
- "Clean architecture" skills renamed to `<stack>-architecture` so all four stacks line up.
- Android scaffold restructured to **feature-first** packaging (`home/ui/`, `feed/ui/`, `core/{domain,data,ui,navigation}/`). Architecture skill, agents, and `/add-screen`/`/new-feature` all describe the same shape.
- `Outcome<T>` + `DomainError` adopted as the **single canonical error contract** across Android skills, agents, and commands. Boundary adapter `Result<T>.toOutcome(...)` rethrows `CancellationException`.
- Android scaffold ships Route + Screen + Preview + UI test as the canonical screen shape, matching `/add-screen` and `compose-ui`. Coil 3 reuses the Hilt-provided `OkHttpClient` via `SingletonImageLoader.Factory`.
- Android `/init-android-app` collapsed to a thin orchestrator; execution detail lives in `android-app-skeleton`. `/upgrade-deps` is now self-sufficient via `maven-metadata.xml` (no plugin dependency).
- Android MVVM standardized on discrete public ViewModel functions (aligned with "Now in Android"); the sealed `UiAction` MVI pattern is gone.
- `settings.json` harmonized across stacks (single git allow/deny list, `$schema` everywhere). Android test stack pinned to JUnit 4 + MockK + Turbine; Robolectric explicitly excluded. iOS deployment target raised to iOS 18. KMM persistence committed to SQLDelight.
- Per-stack `README.md` and `CLAUDE.md` brought in line with the shipped agent/skill/command set.

### Fixed

- Android scaffold: missing `kotlin-compose` plugin (Kotlin 2.0 requirement), unconditional HTTP logging, hard-coded `https://example.invalid/` base URL, uninjectable `AppPreferences`, light-only `themes.xml`, missing `proguard-rules.pro` stub, unwired Room/DataStore modules.
- Hooks rewritten to parse stdin JSON (current Claude Code contract) with env-var fallback. iOS `pre-commit.sh` now uses `set -o pipefail` so build failures actually block commits.
- Flutter `/init-flutter-app` referenced a leaked sandbox path and used `$1` instead of `$ARGUMENTS`.
- Removed `.DS_Store` files and stale permission entries (`Read`/`Write`/`Edit` listed as Bash patterns) from `settings.json`.

[Unreleased]: https://github.com/dimitriRemoiville/ClaudeCodeMobile/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/dimitriRemoiville/ClaudeCodeMobile/releases/tag/v0.1.0
