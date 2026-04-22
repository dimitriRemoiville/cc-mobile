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
    ├── agents/                    # subagents
    │   ├── kmm-architect.md
    │   ├── kmm-engineer.md
    │   ├── kmm-reviewer.md
    │   ├── kmm-tester.md
    │   └── kmm-build-expert.md
    ├── skills/                    # on-demand playbooks
    │   ├── kmm-architecture/SKILL.md
    │   ├── shared-viewmodels/SKILL.md
    │   ├── ktor-multiplatform/SKILL.md
    │   ├── koin-di/SKILL.md
    │   ├── kmm-testing/SKILL.md
    │   └── kmm-ios-interop/SKILL.md
    └── commands/                  # slash commands
        ├── new-feature.md
        ├── add-usecase.md
        ├── add-viewmodel.md
        └── review-kmm.md
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

- `/new-feature <name>` — scaffold a feature across data + domain + presentation.
- `/add-usecase <feature>/<Name>` — add a use case with a common test.
- `/add-viewmodel <feature>/<Name>` — add a shared ViewModel with UiState/UiEvent/Action.
- `/review-kmm` — delegate a convention-focused review to the `kmm-reviewer` subagent.

## Build and test

```bash
./gradlew :shared:allTests                  # all shared tests (JVM + iOS simulator)
./gradlew :shared:jvmTest                   # JVM-only shared tests
./gradlew :shared:iosSimulatorArm64Test     # iOS simulator tests (Apple Silicon)
./gradlew :androidApp:assembleDebug         # Android debug APK
./gradlew :shared:linkDebugFrameworkIosArm64 # iOS framework
./gradlew :shared:assembleXCFramework       # XCFramework for distribution
```
