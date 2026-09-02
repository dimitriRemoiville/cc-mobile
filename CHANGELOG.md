# Changelog

All notable changes to this repo's Claude Code configurations are logged here. Dates are UTC. See `git log` for per-change rationale.

## [0.4.0] — 2026-09-02

Two threads land together: **progressive disclosure** for the app-skeleton skills, and the **hardening the `android` plugin needed to be accepted into the `gen-e2-marketplace` monorepo** ([PR #6](https://github.com/GLOBAL-PALO-IT/gen-e2-marketplace/pull/6)), ported to `ios/` and synced back into `android/`. The through-line is the same: these configs stopped assuming they were the only thing in the room — a skill no longer loads 500 lines to answer a 20-line question, and no longer treats its own opinions as universal truth about the platform.

### Added

- **Progressive disclosure in the app-skeleton skills (`android`, `ios`).** File templates moved out of the monolithic `SKILL.md` into a `references/` subdirectory (`root-files.md`, `app-module.md`, `core-data.md`, `app-core.md`, `app-target.md`, `tests.md`, and the optional-feature files). Each `SKILL.md` is now a procedure spine whose execution-order steps name the reference they need, and `/init-android-app` / `/init-ios-app` load them step by step instead of reading everything up front. `android-app-skeleton` went from 2115 lines to a 161-line spine; `ios-app-skeleton` from 578 to 127.
- **`schemas/triggers.schema.json`** — a shared schema for tier-1 trigger tests, so a plugin can assert that a given prompt routes to the intended skill (or to none at all).
- **`plugins/cc-mobile-android/tests/triggers.json`** — 17 routing cases: one positive per model-invocable skill plus three anti-triggers (off-topic, a cross-platform SwiftUI prompt, a generic DI explainer).
- **Figma MCP for UI engineering.** Both native plugins declare Figma's official MCP server in `.mcp.json` (`https://mcp.figma.com/mcp`, OAuth — no API key, never contacted unless a Figma URL is supplied). `compose-ui` / `android-ui-engineer` and `swiftui-views` / `ios-ui-engineer` gained the section that makes it usable: pull layout, typography, colour, and spacing from the file, then **translate** the tokens rather than pasting them — onto `MaterialTheme.*` on Android, onto asset-catalog colours and semantic `Font` text styles on iOS. That step is the point: a screen built from Figma literals ignores dark mode and stops laying out at large Dynamic Type sizes.
- **Project-fit guards on every knowledge skill (`ios`, `android`).** Each skill now leads with a `## When this applies` section naming the stack signal it assumes and how to defer when the codebase already chose otherwise — TCA / MVI / VIPER instead of MVVM, UIKit instead of SwiftUI, `swift-dependencies` / Factory instead of a composition root, Alamofire / Apollo instead of URLSession, Core Data / Realm instead of SwiftData, XCTest instead of Swift Testing, Combine instead of async/await. Without these, the skills flagged correct-for-that-project code as violations.
- **Stack detection in `ios-reviewer` and `android-reviewer`.** A parallel grep pass (step 3) that runs *before* any rule is applied. On a mismatch the reviewer surfaces it in the summary ("This project is TCA, not MVVM — findings adapted accordingly") and applies the spirit of each rule to the actual stack. Situational skills now load only when the diff warrants **and** the stack matches.
- **`plugins/cc-mobile-ios/tests/triggers.json`** — the iOS counterpart, 18 tier-1 routing tests (one positive per model-invocable skill, plus three anti-triggers: off-topic, an Android/Compose cross-platform prompt, and a generic DI explainer), validated against `schemas/triggers.schema.json`. Prompts are written to discriminate between the pairs that overlap — `keychain-secure-storage` vs `ios-security`, `swift-style` vs `swift-concurrency`, `swiftui-views` vs `navigation-stack`, `ios-architecture` vs `ios-di`.
- **Build-time config-root rewriting in `build-plugin.sh`.** Source files keep `.claude/skills/…` paths so a stack folder still works when dropped into a project root (README option C); `rewrite_plugin_root` rewrites them to `${CLAUDE_PLUGIN_ROOT}/skills/…` when packaging, so plugin installs resolve too. Anchored on the opening backtick, so prose about copying `.claude/` is untouched. Fixes all four stacks from one source.

### Changed

- **iOS knowledge skills leaned to the project delta.** Generic Swift / SwiftUI / URLSession / SwiftData / Keychain / Swift Testing tutorial content removed and deferred to Apple's documentation; what remains is this project's decisions and the traps they exist to prevent. 2357 → 1634 lines across 15 skills, with the cut budget spent on sharper rules (the `CancellationError`-as-domain-failure trap, `#Predicate` capture hoisting, `.biometryCurrentSet` vs `.userPresence`, the `MockURLProtocol` static-handler race, SPKI pin rotation).
- **`android/` synced with what actually shipped in the marketplace.** The same guard + lean pass, plus the `StandardTestDispatcher` scaffolded tests, the `app-module.md` table of contents, the `format.sh` header fix, and the Tink-over-`EncryptedSharedPreferences` reconciliation.
- **`Skill` dropped from `ios-reviewer` / `android-reviewer` tool lists.** Both preload their base skills via the `skills:` frontmatter block, so the entry bought nothing — and `Skill` isn't guaranteed to be a recognised tool name in the Copilot CLI runtime this repo also targets. Partially reverses the 0.3.0 note below; `kmm-reviewer` and `flutter-reviewer` still grant it and should follow.
- **`ios/CLAUDE.md` error contract now says `Outcome<T>`**, matching `ios-app-skeleton` and `swift-style`. It previously said `Result<T, DomainError>`, which no scaffolded file used.

### Fixed

- **Stale skeleton pointers in the iOS commands.** `/init-ios-app` and `/upgrade-deps` referenced a "Compatibility traps" section that never existed in `ios-app-skeleton`; they now point at the spine's `## Target floor` (promoted from a bold lead-in so the anchor resolves) and at `references/app-features.md` for the iOS 17 deltas. `/init-ios-app` Phase 1 also now explains the `references/` progressive-disclosure model instead of implying the spine holds every template.
- **The CI build, broken by this release's own `build-plugin.sh` change.** `rewrite_plugin_root` shipped with `sed -i ''`, the BSD spelling; GNU sed on the runner read the empty string as the in-place suffix and the script as a filename. The rewrite now goes through a temp file, an invocation form identical on both platforms. The `targets` collection also moved from `[[ test ]] && arr+=(…)` to explicit `if` blocks — under `set -e` a bare `&&` list that fails as a whole is fatal, so a future stack without a `commands/` directory would have aborted the build.
- **`ios-security-reviewer` WebKit guidance.** `WKPreferences.javaScriptEnabled` has been deprecated since iOS 14; the check now targets `WKWebpagePreferences.allowsContentJavaScript` and adds unvalidated `WKScriptMessage` bodies as a script-injection sink.

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
