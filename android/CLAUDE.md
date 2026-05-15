# CLAUDE.md

This file gives Claude Code the project context it needs to work effectively here. Claude Code reads this automatically at the start of every session.

## Project

A native Android application written in **Kotlin** with **Jetpack Compose** as the UI toolkit. The codebase follows **MVVM + Clean Architecture** and uses **Hilt** for dependency injection and **Retrofit** for networking.

## Tech stack

- **Language:** Kotlin (use latest stable, target JVM 17)
- **UI:** Jetpack Compose + Material 3
- **Architecture:** MVVM + Clean Architecture (presentation / domain / data layers)
- **DI:** Hilt (`@HiltAndroidApp`, `@AndroidEntryPoint`, `@HiltViewModel`)
- **Networking:** Retrofit + OkHttp + kotlinx.serialization
- **Async:** Kotlin Coroutines + Flow (prefer `StateFlow` in ViewModels)
- **Navigation:** Jetpack Navigation Compose (type-safe routes)
- **Local storage:** Room for relational data, DataStore for preferences
- **Image loading:** Coil for Compose
- **Testing:** JUnit 4 + MockK + Turbine (Flow testing) for unit tests, Compose UI tests, Hilt testing. JUnit 5 is fine in greenfield modules that don't need `androidx.test.*` runners, but JUnit 4 is the default so Android instrumentation stays first-class. Robolectric is **not** part of the default stack — prefer pushing Android-framework-bound logic into instrumentation tests (`src/androidTest/`); add Robolectric only deliberately, with a one-page convention authored alongside it.

## Module / package layout

The project is **feature-first** — each feature is a top-level package containing only the layers it actually needs. Cross-feature plumbing (network factory, error types, analytics interface, theme, top-level nav) lives under `core/`. See `.claude/skills/android-app-skeleton/SKILL.md` for the canonical layout the scaffold emits.

```
app/src/main/java/<package>/
├── core/
│   ├── domain/           # Outcome, DomainError, analytics interface (framework-free)
│   ├── data/             # Networking, analytics impls, Outcomes adapter (knows frameworks)
│   ├── ui/theme/         # AppTheme, color schemes
│   ├── ui/common/        # Shared composables (TrackScreen, ...)
│   └── navigation/       # AppNavGraph (top-level routes)
└── feature_x/
    ├── data/
    │   ├── remote/       # Retrofit service + DTOs (mapping fn colocated)
    │   ├── local/        # Room DAO + entities (only if the feature owns its own table)
    │   └── repository/   # RepositoryImpl
    ├── domain/
    │   ├── model/        # Plain Kotlin domain models
    │   ├── repository/   # Repository interfaces (return Outcome<T>)
    │   └── usecase/      # Use cases (one class per action)
    └── ui/
        ├── <Screen>UiState.kt / <Screen>ViewModel.kt
        ├── <Screen>Screen.kt        # stateless Screen + Route wrapper + Preview(s)
        └── <Screen>Route.kt         # @Serializable destination
```

Dependency direction is always **ui → domain ← data**, *per feature*. The domain layer has no Android or framework dependencies. Don't grow a global `ui/`, `domain/`, or `data/` next to features — that's the layer-first shape this project deliberately avoids.

ViewModels expose user actions as **discrete public functions** (`fun retry()`, `fun submit(...)`); Composables take one lambda per action. This matches Google's [Now in Android](https://github.com/android/nowinandroid) and the standard MVVM shape. A sealed `<Screen>Action.kt` is an MVI escalation reserved for screens with ≥5 distinct interactions.

## Conventions

**Naming**
- Composables: `PascalCase`, noun-based (`UserProfileScreen`, `PrimaryButton`).
- ViewModels: `<Feature>ViewModel`.
- Use cases: verb-based (`GetUserProfileUseCase`, `SubmitOrderUseCase`).
- Repository interfaces in `domain/`, implementations in `data/` suffixed `Impl`.

**State**
- Each screen has a `UiState` data class (preferably sealed when there are truly distinct states).
- ViewModels expose `StateFlow<UiState>`; collect with `collectAsStateWithLifecycle()`.
- One-off effects (navigation, snackbar) use a `Channel<UiEvent>` exposed as a `Flow`.

**Composables**
- Stateless composables take state + callbacks. Stateful wrappers own the `viewModel()`.
- Always provide a `@Preview` with a representative state.
- Hoist state; avoid `remember { mutableStateOf(...) }` for anything the ViewModel owns.
- Pass `Modifier` as the first optional parameter, default `Modifier`.

**Coroutines**
- Use structured concurrency. `viewModelScope` in ViewModels, `Dispatchers.IO` for IO.
- Never block the main thread. Prefer `Flow` over `LiveData` in new code.

**Errors**
- Domain layer returns `Outcome<T>` carrying `DomainError` on failure — never throws across layers, never returns `Result<T>` on a domain-facing signature.
- Repositories map exceptions at the boundary via `runCatching { ... }.toOutcome(::toDomainError)` (helpers in `core/data/network/Outcomes.kt`).
- See `android-architecture` skill for the full pattern and the `runCatching.fold` pitfall.

## Build

- Gradle with the **version catalog** (`gradle/libs.versions.toml`) — add dependencies there, not inline.
- Kotlin DSL (`build.gradle.kts`).
- Run locally: `./gradlew assembleDebug`
- Unit tests: `./gradlew test`
- Instrumentation tests: `./gradlew connectedDebugAndroidTest`
- Lint + format: `./gradlew ktlintCheck detekt` (if configured)

## What Claude should do

- **Always prefer editing existing files** over creating new ones. Only create files when a new feature genuinely needs them.
- **Follow the layer boundaries.** No Android / Retrofit / Room imports in `core/domain/` or `<feature>/domain/`. No Compose imports outside `core/ui/` or `<feature>/ui/`.
- **Write tests** for new use cases and ViewModels. Compose UI tests for new screens where practical.
- **Use the version catalog** when adding dependencies.
- **Respect Kotlin idioms**: data classes, sealed classes/interfaces, extension functions, scope functions used sparingly and intentionally.
- **Keep Composables small.** Extract children when a function body exceeds ~60-80 lines or nesting exceeds 3 levels — but the real rule is readability and single-responsibility, not the line count. See `.claude/skills/compose-ui/SKILL.md` for the rationale.

## Specialist agents

Use the `Task` tool with these subagents for focused work (see `.claude/agents/`):

- `android-architect` — architectural decisions, module boundaries, trade-offs.
- `android-ui-engineer` — building Compose screens and components.
- `android-reviewer` — code review focused on Kotlin/Android idioms.
- `android-tester` — writing unit, Flow, and Compose UI tests.
- `android-build-expert` — Gradle, version catalog, build performance, KSP/kapt issues.
- `android-security-reviewer` — auth, secrets, network calls crossing trust boundaries, manifest changes.
- `android-a11y-reviewer` — Compose semantics, content descriptions, tap targets, TalkBack.
- `android-performance-analyst` — jank, cold-start regressions, Macrobenchmark / Baseline Profile work.
- `android-release-engineer` — version bumps, signing config, Play Console metadata, fastlane / `gradle publish`.

## Useful slash commands

See `.claude/commands/`:

- `/init-android-app` — scaffold a brand-new Android app from scratch (AGP 9, Hilt, Compose, Home + Feed/Profile bottom-nav, analytics layer). Resolves every dependency version online before writing files.
- `/new-feature` — scaffold a full feature (data + domain + presentation).
- `/add-screen` — add a Compose screen + ViewModel + UiState.
- `/add-usecase` — add a use case with a test.
- `/add-migration` — add a Room schema migration.
- `/upgrade-deps` — refresh `libs.versions.toml` against published Maven metadata.
- `/fix-tests` — investigate + fix failing unit tests on the current branch.
- `/review-android` — run a review pass with `android-reviewer`.
