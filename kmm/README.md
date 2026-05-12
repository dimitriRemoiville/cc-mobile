# KMM Claude Code setup

Opinionated Claude Code configuration for a Kotlin Multiplatform Mobile project with a shared business-logic module consumed by native UIs (Jetpack Compose on Android, SwiftUI on iOS).

## Stack

- **Shared language:** Kotlin Multiplatform — `commonMain`, `androidMain`, `iosMain`.
- **UI:** Native per platform — Jetpack Compose (Android) + SwiftUI (iOS). Not Compose Multiplatform. Rendering lives in the companion `cc-mobile-android` / `cc-mobile-ios` plugins; this stack's `kmm-engineer` agent owns shared business logic and stops at the shared-ViewModel boundary.
- **Architecture:** MVVM + Clean Architecture inside `commonMain`. Shared ViewModels extend `androidx.lifecycle:lifecycle-viewmodel` (multiplatform).
- **State:** `StateFlow<UiState>` + `Channel<UiEvent>` + sealed `Action`. Platform navigation stays in each app.
- **DI:** Koin (Hilt is Android-only and not used here). Platform-specific bindings live in `androidMain` / `iosMain` modules.
- **Networking:** Ktor Client in `commonMain`. Engine injected per platform (OkHttp on Android, Darwin on iOS).
- **Serialization:** `kotlinx.serialization`.
- **Testing:** `kotlin.test` + `kotlinx-coroutines-test`. Ktor `MockEngine` for repository tests.

## Layout

```
kmm/
├── CLAUDE.md                      # always-loaded project context
├── README.md                      # this file
└── .claude/
    ├── settings.json              # Gradle/Xcode/git permissions
    ├── hooks.json                 # PostToolUse + PreToolUse hook wiring
    ├── hooks/                     # Versioned hook scripts
    │   ├── format.sh              # ktlint (Kotlin) + swiftformat (Swift glue) on edited files
    │   └── pre-commit.sh          # :shared:allTests + :androidApp:lintDebug before `git commit`
    ├── agents/                    # subagents
    │   ├── kmm-architect.md
    │   ├── kmm-engineer.md
    │   ├── kmm-reviewer.md
    │   ├── kmm-tester.md
    │   ├── kmm-build-expert.md
    │   ├── kmm-security-reviewer.md
    │   ├── kmm-a11y-reviewer.md
    │   ├── kmm-performance-analyst.md
    │   └── kmm-release-engineer.md
    ├── skills/                    # on-demand playbooks
    │   ├── kmm-architecture/SKILL.md
    │   ├── kmm-app-skeleton/SKILL.md
    │   ├── kmm-ios-interop/SKILL.md
    │   ├── kmm-testing/SKILL.md
    │   ├── shared-viewmodels/SKILL.md
    │   ├── koin-di/SKILL.md
    │   ├── ktor-multiplatform/SKILL.md
    │   ├── kotlinx-serialization/SKILL.md
    │   ├── multiplatform-settings/SKILL.md
    │   ├── sqldelight-persistence/SKILL.md
    │   └── xcframework-distribution/SKILL.md
    └── commands/                  # slash commands
        ├── init-kmm-app.md
        ├── new-feature.md
        ├── add-usecase.md
        ├── add-viewmodel.md
        ├── add-migration.md
        ├── review-kmm.md
        ├── upgrade-deps.md
        └── fix-tests.md
```

## Conventions at a glance

- `presentation → domain ← data` inside `commonMain`. No leaks across.
- `commonMain` has zero Android/iOS imports (other than the multiplatform `lifecycle-viewmodel` API).
- `expect`/`actual` only when the API surface is simple (a handful of methods on a value-like type). Otherwise, use an interface in `commonMain` + Koin platform module binding.
- Shared ViewModels expose three things: `state: StateFlow<UiState>`, `events: Flow<UiEvent>`, `onAction(...)`.
- Errors cross the repository boundary as `DomainError` values. Repositories return `Result<T>`. `CancellationException` is always rethrown.
- Tests default to `commonTest`; promote to a platform test set only if the code under test is platform-specific. No MockK or JUnit in `commonTest`.

## iOS interop

The public `commonMain` surface is also the Swift surface. Follow `.claude/skills/kmm-ios-interop/SKILL.md` before exposing anything new: no `inline`, no default arguments, shallow sealed hierarchies, `@Throws` on throwing suspends, no `internal` types leaking.

## Slash commands

- `/init-kmm-app [package_id]` — scaffold a brand-new KMM project from scratch (`:shared` with commonMain/androidMain/iosMain, `:androidApp` Compose, `iosApp/` SwiftUI, Ktor Client, Koin, optional SQLDelight). Resolves all Maven + GitHub-Releases versions online before writing files.
- `/new-feature <name>` — scaffold a feature across data + domain + presentation.
- `/add-usecase <feature>/<Name>` — add a use case with a common test.
- `/add-viewmodel <feature>/<Name>` — add a shared ViewModel with UiState/UiEvent/Action.
- `/add-migration <name>` — add a SQLDelight schema migration.
- `/upgrade-deps` — refresh `libs.versions.toml` against published Maven metadata.
- `/fix-tests` — investigate + fix failing common or platform tests on the current branch.
- `/review-kmm` — delegate a convention-focused review to the `kmm-reviewer` subagent.

## Specialist agents — quick reference

| Agent | Use for |
|---|---|
| `kmm-architect` | Module boundaries, source-set decisions, `expect`/`actual` vs. interface-injection trade-offs |
| `kmm-engineer` | Building repositories, use cases, ViewModels in `commonMain` |
| `kmm-reviewer` | Code review focused on KMP idioms and iOS interop surface |
| `kmm-tester` | `kotlin.test` + `kotlinx-coroutines-test` suites for common code |
| `kmm-build-expert` | KMP Gradle plugin, source-set wiring, XCFramework / CocoaPods / SPM distribution |
| `kmm-security-reviewer` | Token storage on each platform, network calls, KMP-side keystore/keychain glue |
| `kmm-a11y-reviewer` | Both platforms' UI for shared-layer pitfalls (locale-insensitive formatting, color-only enums) |
| `kmm-performance-analyst` | Shared cold-start cost, Ktor + serialization overhead, framework-link size |
| `kmm-release-engineer` | Version bumps, XCFramework publishing, dual-platform release coordination |

## Build and test

```bash
./gradlew :shared:allTests                  # all shared tests (JVM + iOS simulator)
./gradlew :shared:jvmTest                   # JVM-only shared tests
./gradlew :shared:iosSimulatorArm64Test     # iOS simulator tests (Apple Silicon)
./gradlew :androidApp:assembleDebug         # Android debug APK
./gradlew :shared:linkDebugFrameworkIosArm64 # iOS framework
./gradlew :shared:assembleXCFramework       # XCFramework for distribution
```
