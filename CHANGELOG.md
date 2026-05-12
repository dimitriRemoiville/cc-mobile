# Changelog

All notable changes to this repo's Claude Code configurations are logged here. Dates are UTC.

## [Unreleased]

### Added

- Android: new `core/data/network/Outcomes.kt` in the `android-app-skeleton` scaffold — the **canonical `Result<T>.toOutcome(...)` adapter + `toDomainError(...)` mapper** for the project. Every repository now goes through this single boundary instead of open-coding `runCatching { ... }.fold(...)` (which silently swallows `CancellationException` and breaks coroutine cancellation). The skeleton's `RemoteDataSource.ping()`, the `retrofit-networking` repository pattern, the `android-architecture` data-layer example, `kotlin-style`, `android/CLAUDE.md`, and `android-reviewer` all now reference this single helper instead of redefining (or, worse, mis-defining) it inline.
- Android: Coil 3 wired into `android-app-skeleton` (`coil = "<latest-stable>"` ref + `coil-compose` and `coil-network-okhttp` library entries + `implementation(...)` lines in `app/build.gradle.kts`). `/init-android-app` Phase 1.5 now resolves Coil via `https://repo1.maven.org/maven2/io/coil-kt/coil3/coil-compose/maven-metadata.xml`. `android/CLAUDE.md` listed Coil as the project's image loader but the scaffold never shipped it — fixed.
- Android: new focused `android-release` skill (`android/.claude/skills/android-release/SKILL.md`) covering version-bump rules, the `keystore.properties`-driven signing config, fastlane changelog layout, Baseline Profile regeneration, Crashlytics mapping upload, bundle vs APK, and the pre-release Gradle command sequence. Authored deliberately small (~120 lines) so `android-release-engineer` can preload it without paying the cost of the much larger `android-app-skeleton` skill.
- Android: `kotlin-compose` plugin alias (`org.jetbrains.kotlin.plugin.compose`) added to `gradle/libs.versions.toml`, the root `build.gradle.kts`, and the `:app` `build.gradle.kts` in `android-app-skeleton`. Required since Kotlin 2.0 — without it any module that sets `buildFeatures.compose = true` aborts with `Compose Compiler is required, but not applied`. The "Compose Compiler" trap-table cell, AGP 8.x escape-hatch note, and Hard rules section now all describe this consistently. Without this fix, every freshly scaffolded `/init-android-app` would fail to compile.
- Android: `/init-android-app` Phase 0 now collects an **API base URL** per flavor (defaults `https://api.dev.example.com/`, `https://api.example.com/`; trailing slash enforced). The skeleton's `app/build.gradle.kts` wires it via `buildConfigField("String", "API_BASE_URL", ...)` per flavor (with a `FLAVORS_OFF` fallback in `defaultConfig`), and `data/di/DataModule.kt` now reads `BuildConfig.API_BASE_URL` instead of the placeholder `https://example.invalid/` URL it used to hard-code (which made first-call networking fail at module construction).
- Android: `/init-android-app` and `android-app-skeleton` now run a **full `:app:assembleDevDebug`** as part of the post-scaffold validation step (in addition to `compileDebugKotlin` and `testDebugUnitTest`). The full assemble is what catches missing Gradle plugins, manifest merger errors, and unresolved dependencies — `compileDebugKotlin` alone misses these.
- Android: `/add-screen` now generates a Compose UI test under `app/src/androidTest/.../<Screen>Test.kt` covering the happy-path render of the `Success` state (semantic matchers, `createComposeRule`, no Hilt boilerplate). Opt out with `--no-test`.

### Changed

- Android: scaffold restructured to **feature-first** packaging. `android-app-skeleton` now emits `home/ui/`, `feed/ui/`, `profile/ui/` per feature, with cross-feature plumbing under `core/{domain,data,ui,navigation}/` (was a global layer-first split: `ui/`, `domain/`, `data/` at the package root). Every code template, import, test path, and section heading in the skill was updated. `android/CLAUDE.md`, `android-architecture`, `/new-feature`, `/add-screen`, and `/add-usecase` now describe the same feature-first shape (was contradicting the scaffold). `android-reviewer` flags the layer-first shape as a layer violation. The "ui/" name (not "presentation/") is now consistent across the architecture skill and the scaffold.
- Android: `android-release-engineer` agent body trimmed to defer to its preloaded `android-release` skill instead of restating signing-config, pre-release checklist, etc. The body's stale "keystore creds in `~/.gradle/gradle.properties`" guidance (contradicted the `keystore.properties` convention in the preloaded skill) is gone, and the iOS-only `pilot` reference is replaced with `supply --track internal` (the actual Android equivalent for internal-test uploads).
- Android: `Outcome<T>` + `DomainError` is now the **single canonical error contract** across the stack. `kotlin-style`, `retrofit-networking`, `android-architecture`, `android-testing`, `android-reviewer`, `add-usecase`, and `android/CLAUDE.md` all agreed on three different shapes before today (some `Result<T>` + a `mapError` helper that would have forced `DomainError : Throwable`, some `Outcome` only, some both). `retrofit-networking` now defines a single `Result<T>.toOutcome(...)` adapter at the data-layer boundary that also rethrows `CancellationException` (which `runCatching` otherwise swallows). The reviewer agent flags any `Result<T>` on a domain-facing signature.
- Android: `/init-android-app` collapsed from a 158-line copy of the skeleton's content into a ~95-line orchestrator that owns only Phase 0 (questionnaire), Phase 1.5 (version-resolution URL table), and pointers into the skeleton. Execution order, file templates, hard rules, and post-init checklist are now exclusively in `android-app-skeleton`. Eliminates the documentation-drift class where edits to one file silently outdate the other.
- Android: `/upgrade-deps` is now self-sufficient — walks each `[versions]` ref via `WebFetch` against the registry's `maven-metadata.xml` (the same mechanism `/init-android-app` Phase 1.5 uses), with the Ben-Manes `gradle-versions-plugin` listed only as an optional speedup. Previously the command was a no-op on a freshly-scaffolded project (which doesn't ship the plugin). Now also cross-references the skeleton's "Compatibility traps" table and runs `assembleDevDebug` post-bump.
- Android: `/fix-tests` `--filter` documented as a Gradle test-filter glob (`'*OrderViewModelTest*'`); dropped the misleading `--continue` flag. Bare class names won't match nested classes (`Foo$Nested`) — the doc now spells this out.
- Android: `/add-migration` switched to `AskUserQuestion` (added to `allowed-tools`) with a structured single-select prompt for the schema-change shape — operation, target table, column type, nullability, default — instead of asking the user to write SQL by hand and rejecting obviously-broken combinations (e.g. `NOT NULL` add without a default) before generating the migration.
- Android: `/add-usecase` snippet uses `Outcome<T>` (was `Result<T>`); explicitly references the "When to add a use case" rubric in `android-architecture` and suggests `android-architect` delegation when the call is ambiguous.
- Android: agent `skills:` audit:
  - `android-tester` now preloads `compose-ui` (was missing — but the agent writes Compose UI tests).
  - `android-architect` now preloads `android-app-skeleton` (the "Module or package?" decision rationale lives there).
  - `android-release-engineer` no longer preloads the 1,361-line `android-app-skeleton` skill in full — it now declares the new focused `android-release` skill instead. (`validate.sh` blocked the empty `skills:` block I tried first; the new skill is the right answer.)
- Android: `android-security-reviewer`, `android-a11y-reviewer`, and `android-performance-analyst` had their body-link skill references stripped (`Consult [skill](../skills/.../SKILL.md)`). The skills are already preloaded via frontmatter, and the relative paths broke when the agent ran from the packaged plugin location.
- Android: `android-reviewer` description tightened — explicitly anti-triggers on partial / WIP edits ("Use after a coherent change is complete — at PR time, when the user explicitly says 'review', or when a multi-file feature has just been finished. Do NOT auto-fire after individual edits"). Previously fired after "any substantive change", which guaranteed over-activation in long sessions.
- Android: hooks rewritten to parse stdin JSON (the modern Claude Code hook contract) with env-var fallback for older versions. `pre-commit.sh` now also short-circuits when no Kotlin / Gradle / Android-resource files are staged — touch-only commits to docs / CI no longer pay for a 30 s+ Gradle run. Smoke-tested all skip paths (`exit 0`, no Gradle invocation).
- Android: `android-architecture` H1 changed from "Clean Architecture in this project" to "Android architecture (MVVM + Clean)" so the file's name and title agree.
- Android: `datastore-preferences` multi-process artifact name corrected to `androidx.datastore:datastore-core-multiprocess` (with a catalog snippet pinning it to the existing `datastore` ref so the single-process and multi-process variants stay in lockstep).
- Android: `compose-ui` skill `description:` no longer claims ownership of "navigation destinations" — that's `navigation-compose`'s job, and the overlap caused both skills to auto-load on the same nav request.
- Android: `hilt-di` `provideRetrofit` snippet now declares `provideJson()` and takes `json: Json` as a parameter — previously the `json.asConverterFactory(...)` call referenced an undeclared symbol (anyone copy-pasting hit `Unresolved reference: json`).
- Android: `/add-screen` Compose UI test skeleton now uses the `<Screen>Screen` naming the rest of the project uses (file `<Screen>Screen.kt`, composable `<Screen>Screen(...)`, test class `<Screen>ScreenTest`). Previously the test called `<Screen>(...)` against a file named `<Screen>Screen.kt` — the agent would either invent the wrong name or stop to ask.
- Android: `/init-android-app` Phase 0 Q8 now spells out that flavor names are **fixed** to `dev` / `prod` for the `INCLUDE_FIREBASE` per-flavor `google-services.json` story to line up; renaming or adding flavors (e.g. `staging`) is an `android-build-expert` task post-scaffold.
- Android: `android-release` pre-release checklist drops `:app:assembleRelease` from the gate (`bundleRelease` already runs the same R8 + signing pipeline; adding both ~doubled the time for no extra coverage). `assembleRelease` is documented as needed only for sideload / internal QA `.apk` distribution.
- Android: `android-tester` JUnit guidance now mirrors `android/CLAUDE.md` precisely — JUnit 4 default for instrumentation `androidx.test.*` runner compatibility, JUnit 5 fine in greenfield non-instrumentation modules.
- Android: `format.sh` PostToolUse hook no longer falls back to `./gradlew ktlintFormat` when the local `ktlint` binary is missing — the Gradle task formats the whole project on every Edit, which is surprising scope creep for a single-file change. Hook now prints a one-line note pointing at the manual command instead.
- Root `README.md` cross-stack table — Android's "Error surface" cell now reads `sealed Outcome<T> carrying DomainError` (was just `sealed DomainError`) to reflect the canonicalization above. Other stacks unchanged.
- `android/CLAUDE.md` Robolectric mention reframed: explicitly **not** part of the default test stack; framework-bound logic should land in instrumentation tests in `src/androidTest/`. Aligns CLAUDE.md with the rest of the config (no skill, agent, or template uses Robolectric).

### Fixed

- Android: scaffolded `RemoteDataSource.ping()` no longer silently swallows `CancellationException`. Previously it open-coded `runCatching { ... }.fold(onSuccess, onFailure)` — `runCatching` catches `Throwable` (including `CancellationException`), and the open-coded `fold` didn't rethrow it, so every coroutine cancellation through the data source ended in `Outcome.Failure(DomainError.Unknown(...))` instead of bubbling cancellation. The example was the project's most-copied data-source shape; now goes through the canonical `Result<T>.toOutcome(...)` adapter that rethrows `CancellationException`.
- Android: `data/di/DataModule.kt` in the skeleton now reads `BuildConfig.API_BASE_URL` instead of hard-coding `https://example.invalid/`. The previous template would compile and install fine but throw at first network call — a silent footgun that survived because the smoke test (now `assembleDevDebug`) didn't exercise the runtime path.
- Android: hooks no longer rely on `CLAUDE_TOOL_INPUT_command` / `CLAUDE_FILE_PATHS` env vars as the primary input. The current Claude Code hook contract is JSON on stdin; the env vars aren't populated by recent versions, which meant `pre-commit.sh` was a silent no-op (the `case` filter never matched and the gate never blocked anything). stdin parsing is now primary, env-var fallback secondary.


- `.gitignore` at repo root.
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
- Android test stack explicitly set to JUnit 4 + MockK + Turbine (previously ambiguous "JUnit 4/5"). Robolectric is intentionally **not** part of the default stack — `android/CLAUDE.md` now spells this out and points framework-bound logic at instrumentation tests in `src/androidTest/`.
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
