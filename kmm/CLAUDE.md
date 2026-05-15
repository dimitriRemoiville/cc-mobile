# CLAUDE.md — KMM stack

This file gives Claude Code the project context it needs to work effectively on the **Kotlin Multiplatform Mobile (KMM)** target. Claude Code reads this automatically at the start of every session in this folder.

## Project

A mobile app built on **Kotlin Multiplatform**. Shared logic lives in a Kotlin common module and runs on both Android and iOS; the UI is **native per platform** (Jetpack Compose on Android, SwiftUI on iOS).

This stack is the sibling of the `android/` and `ios/` setups. The shared module is consumed as a Gradle module from the Android app and as an XCFramework (or via CocoaPods / SPM) from the iOS app.

## What's shared

Everything from the domain down, plus ViewModels:

- **Domain:** models, use cases, repository interfaces.
- **Data:** Retrofit-equivalent via **Ktor Client**, DTOs via **kotlinx.serialization**, repository implementations, mappers.
- **Persistence:** SQLDelight (single source of truth for this repo — do not mix Room-KMP alongside).
- **ViewModels:** built on `androidx.lifecycle:lifecycle-viewmodel` (multiplatform-ready), exposing `StateFlow<UiState>` and a `Channel<UiEvent>`.

## What stays platform-native

- **UI:** Jetpack Compose on Android (see `../android/`), SwiftUI on iOS (see `../ios/`).
- **Navigation:** Navigation-Compose on Android, `NavigationStack` on iOS. The shared module exposes state + actions; each platform decides how to route.
- **Platform integrations:** camera, push, notifications, deep links — thin wrappers in `androidMain/` and `iosMain/` behind a common `expect` declaration.

## Tech stack

- **Kotlin:** latest stable, JVM target 17 for Android, iOS (arm64, simulatorArm64, x64) targets for Apple.
- **Coroutines:** `kotlinx-coroutines-core` (multiplatform).
- **Serialization:** `kotlinx-serialization-json`.
- **DateTime:** `kotlinx-datetime`.
- **Networking:** **Ktor Client** (`ktor-client-core`, `ktor-client-content-negotiation`, `ktor-serialization-kotlinx-json`, platform engines: OkHttp on Android, Darwin on iOS).
- **DI:** **Koin** (`koin-core` in common; `koin-android` in `androidMain`). Not Hilt — Hilt is Android-only.
- **Persistence:** SQLDelight (with platform drivers: `android-driver`, `native-driver`); `multiplatform-settings` for key-value prefs.
- **Logging:** `co.touchlab:kermit` for multiplatform logging.
- **Testing:** `kotlin.test` + `kotlinx-coroutines-test`.

## Source set layout

```
kmm/
├── shared/                           # Kotlin Multiplatform module
│   ├── build.gradle.kts
│   └── src/
│       ├── commonMain/kotlin/        # runs on all platforms
│       │   └── com/example/app/
│       │       ├── domain/{model, repository, usecase}
│       │       ├── data/{remote, local, mapper, repository}
│       │       └── presentation/{<feature>/UiState, ViewModel, ...}
│       ├── commonTest/kotlin/
│       ├── androidMain/kotlin/       # JVM/Android only (OkHttp engine, Android driver, Android context)
│       └── iosMain/kotlin/           # Apple targets (Darwin engine, native driver)
├── androidApp/                       # Android executable — consumes :shared
│   └── src/main/kotlin/...
└── iosApp/                           # Xcode project — consumes shared.framework
    └── ...
```

Dependency direction inside `shared/`: `presentation → domain ← data`. Domain is framework-free Kotlin only.

## Conventions

**`expect` / `actual`**
- Use `expect`/`actual` **sparingly** — only where a platform truly differs (HTTP engine, filesystem, Keychain/Keystore, date formatting).
- Put the `expect` in `commonMain`, the `actual`s in `androidMain` and `iosMain`.
- Prefer a common interface with platform-provided implementations (injected via Koin) over `expect`/`actual` when the surface is wide.

**ViewModels in common code**
- Extend `androidx.lifecycle.ViewModel` from `androidx.lifecycle:lifecycle-viewmodel` — it's now multiplatform.
- Expose `StateFlow<UiState>`; one-off events via `Channel<UiEvent>` + `receiveAsFlow()`.
- Each platform binds the ViewModel:
  - Android: `hiltViewModel()`-like pattern but via Koin (`koinViewModel()`), or construct manually.
  - iOS: wrap the ViewModel in a `@Observable` Swift class that forwards state and actions.

**Naming**
- Same as the Android stack: `PascalCase` types, `camelCase` members, use-case names are verbs (`GetOrderUseCase`).
- Keep package paths consistent across source sets: `com.example.app.feature.x.domain.model`.

**Coroutines**
- `CoroutineDispatcher` is **injected**, never referenced directly. Provide `Dispatchers.IO` / `Dispatchers.Default` via Koin; in tests inject a `TestDispatcher`.
- No `GlobalScope`.
- Shared `ViewModel.viewModelScope` works on both platforms.

**Errors**
- Domain layer returns `Result<T>` or a sealed `Outcome<T>`. Don't throw platform exceptions across layer boundaries.
- Ktor exceptions (`HttpRequestTimeoutException`, `ResponseException`, …) are mapped at the repository.

**iOS interop**
- Keep the public API of `commonMain` **Swift-friendly**: avoid `inline` functions, default arguments on public APIs (they don't translate cleanly), sealed classes with generic bounds beyond a single level, and internal-only types leaking.
- Types crossing into Swift should be `data class` / `sealed class` / plain interfaces. See `.claude/skills/kmm-ios-interop/SKILL.md` for the full list.

## Build

- Gradle with the Kotlin Multiplatform plugin + **version catalog** (`gradle/libs.versions.toml`).
- Android: `./gradlew :androidApp:assembleDebug`.
- iOS framework: `./gradlew :shared:linkDebugFrameworkIosSimulatorArm64` (or `assembleXCFramework` for the packaged form).
- Common tests: `./gradlew :shared:allTests` (runs JVM + iOS simulator tests).

## What Claude should do

- **Prefer editing existing files** over creating new ones.
- **Put code in the highest source set that can hold it.** Common-first; platform-specific only when necessary.
- **Respect layer boundaries.** No Android imports in `domain/`. No Ktor / SQLDelight imports in `domain/`. No `presentation/` from `data/`.
- **Use `expect`/`actual` judiciously.** Interfaces injected via Koin are usually a better option.
- **Tests live in `commonTest`** when the code is in `commonMain`. Platform-specific tests live in `androidUnitTest` / `iosTest`.
- **ViewModels belong in `presentation/` inside `commonMain`.** Not in `androidApp/` or `iosApp/`.

## Specialist agents

Use the `Task` tool with these subagents for focused work (see `.claude/agents/`):

- `kmm-architect` — module boundaries, source-set decisions, `expect`/`actual` vs. interface-injection trade-offs.
- `kmm-engineer` — building repositories, use cases, ViewModels in `commonMain`.
- `kmm-reviewer` — code review focused on KMP idioms and iOS interop surface.
- `kmm-tester` — `kotlin.test` + `kotlinx-coroutines-test` suites for common code.
- `kmm-build-expert` — KMP Gradle plugin, source-set wiring, XCFramework / CocoaPods / SPM distribution.
- `kmm-security-reviewer` — token storage on each platform, network calls, KMP-side keystore/keychain glue.
- `kmm-performance-analyst` — shared cold-start cost, Ktor + serialization overhead, framework-link size.
- `kmm-release-engineer` — version bumps, XCFramework publishing, dual-platform release coordination.

## Useful slash commands

See `.claude/commands/`:

- `/init-kmm-app` — scaffold a brand-new KMM project from scratch (`:shared` with commonMain/androidMain/iosMain, `:androidApp` Compose, `iosApp/` SwiftUI, Ktor Client, Koin, optional SQLDelight). Resolves all Maven + GitHub-Releases versions online before writing files.
- `/new-feature` — scaffold a full feature in `shared/` (data + domain + presentation ViewModel).
- `/add-usecase` — add a use case + test in `commonMain` / `commonTest`.
- `/add-viewmodel` — add a shared ViewModel with `StateFlow<UiState>` + UiEvent channel.
- `/add-migration` — add a SQLDelight schema migration.
- `/upgrade-deps` — refresh `libs.versions.toml` against published Maven metadata.
- `/fix-tests` — investigate + fix failing common or platform tests on the current branch.
- `/review-kmm` — delegate a review pass to `kmm-reviewer`.

## Relationship to sibling setups

- `../android/` — governs the **UI** layer that consumes `:shared`.
- `../ios/` — governs the **UI** layer that consumes the shared framework.
- When the Android or iOS app adds a feature, the business logic for it should live here in `shared/`, not duplicated in each native app.
