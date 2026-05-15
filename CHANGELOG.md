# Changelog

All notable changes to this repo's Claude Code configurations are logged here. Dates are UTC. See `git log` for per-change rationale.

## [0.3.0] — 2026-05-15

### Added

- **`scripts/check-drift.sh`** — cross-stack structural-parity checker. Flags missing agent roles, missing shared commands, missing prefixed skill topics, and missing required agent frontmatter keys across the four stacks. Bash 3.2-compatible (macOS default). Allowlist mechanism (`INTENTIONAL_GAPS`, `KNOWN_DIVERGENT_COMMANDS`, `is_stack_specific_command`) for asymmetries that exist by design.
- **`.github/workflows/validate.yml`** — CI workflow running `validate.sh` + `check-drift.sh` on every push and pull request, plus a plugin-rebuild step that fails if `plugins/` is out of sync with the source stack folders.
- **`validate.sh` gains `check_version_alignment`** — verifies `metadata.version` in both marketplace manifests matches the highest per-plugin version, catching the split-brain risk where one bumps without the other.
- **`kmm-performance` skill** — Darwin dispatcher choice, ObjC interop allocation costs, framework-link size, `kotlinx.serialization` cost on Darwin, Ktor engine reuse, cold-start cost on iOS. Wired into `kmm-performance-analyst`'s skill preload.

### Changed

- **Reviewer skill preload trimmed.** All four main reviewers (`android-reviewer`, `ios-reviewer`, `kmm-reviewer`, `flutter-reviewer`) used to preload 3–4 skills regardless of what changed. Now preload architecture + base style only; the `Skill` tool is granted so situational skills (`compose-ui`, `swiftui-views`, `swift-concurrency`, `widgets-and-screens`, `bloc-state`, etc.) load on demand based on the diff. Honors the "keep the list tight" guidance in each stack's `CLAUDE.md`.
- **Reviewer trigger cadence standardized.** `ios-reviewer`, `kmm-reviewer`, and `flutter-reviewer` now mirror `android-reviewer`'s cautious wording: fire on coherent changes (PR time, multi-file features, explicit `/review` requests), not on partial edits. Reduces spurious mid-work reviews.
- **`android-architecture` skill is now the canonical source of truth** for the `Outcome<T>` / `DomainError` / `runCatching.fold` pitfall rule. `android/CLAUDE.md` and `android/.claude/commands/new-feature.md` no longer restate the rule — they point at the skill.
- **Pre-commit hooks across all four stacks short-circuit non-`git commit` Bash calls in ~5 ms** (was ~50 ms). The cheap-grep substring check on stdin runs before the Python-based JSON parser, so unrelated Bash calls (`ls`, `git status`, `./gradlew assembleDebug`) pay almost no overhead.
- **`android-security-reviewer`** trigger list dropped the iOS-only `Keychain` keyword and replaced iOS-only `ATS misconfig` with Android's `Network Security Config misconfig`.
- **`ios-security-reviewer`** trigger list dropped the Android-only `Keystore` keyword; biometrics spelled out as `LAContext / LocalAuthentication`; App Check / DeviceCheck broadened to include `App Attest`.
- **`flutter-architect`** description gained the trade-off pattern list (Bloc vs. Cubit, freezed unions, feature-local DI) to match the triggering shape of the other three architects.
- **`README.md`** "every stack ships nine agents" claim updated to reflect KMM's eight (no `kmm-a11y-reviewer`).
- **`kmm/README.md`** skill list now lists `kmm-performance` and `kmm-release` (previously missing). `ios/README.md` and `flutter/README.md` skill lists now include `ios-release` and `flutter-release` respectively.

### Removed

- **`kmm-a11y-reviewer` agent** — KMM ships no shared UI, so the agent had no playbook (no `kmm-accessibility` skill ever existed) and was aspirational at best. Use `android-a11y-reviewer` / `ios-a11y-reviewer` from the native plugins instead. Drift script allowlists this gap via `INTENTIONAL_GAPS`.

### Fixed

- **`.lean-ctx/`** added to `.gitignore` to prevent accidental commits of the local context graph.

## [0.2.0] — 2026-05-13

### Added

- **Copilot CLI marketplace support.** The repo now ships a `.github/plugin/marketplace.json` alongside the existing `.claude-plugin/marketplace.json`, making the same four plugins installable from both Claude Code and GitHub Copilot CLI.
- `build-plugin.sh` produces dual output per stack: the plugin directory contains `.agent.md` files (Copilot CLI format), while the `.plugin` ZIP contains `.md` files (Claude Code format).
- `validate.sh` gains a `check_marketplace_json` step that parses `.github/plugin/marketplace.json` and verifies every plugin entry resolves to a directory with a `plugin.json` manifest.

### Changed

- Agent files inside `plugins/cc-mobile-*/agents/` are now named `*.agent.md` (was `*.md`). Source files under `<stack>/.claude/agents/` remain `.md` — the rename happens at build time.
- `validate.sh` plugin parity check compares agent base names across the `.md` → `.agent.md` extension difference.

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

[0.3.0]: https://github.com/dimitriRemoiville/cc-mobile/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/dimitriRemoiville/cc-mobile/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/dimitriRemoiville/cc-mobile/releases/tag/v0.1.0
