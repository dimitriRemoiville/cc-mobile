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
- **Testing:** JUnit 4 + MockK + Turbine (Flow testing) for unit tests, Robolectric for Android-framework-bound tests, Compose UI tests, Hilt testing. (JUnit 5 is fine in greenfield modules that don't need `androidx.test.*` runners, but JUnit 4 is the default so Android instrumentation + Robolectric stay first-class.)

## Module / package layout

A typical feature module or package looks like:

```
feature_x/
├── data/
│   ├── remote/      # Retrofit service + DTOs
│   ├── local/       # Room DAO + entities
│   ├── mapper/      # DTO/Entity <-> Domain model
│   └── repository/  # RepositoryImpl
├── domain/
│   ├── model/       # Plain Kotlin domain models
│   ├── repository/  # Repository interfaces
│   └── usecase/     # Use cases (one class per action)
└── presentation/
    ├── <screen>/    # Composable screen + ViewModel + UiState + UiEvent
    └── navigation/  # Route definitions
```

Dependency direction is always **presentation → domain ← data**. The domain layer has no Android or framework dependencies.

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
- Domain layer returns `Result<T>` or a sealed `Outcome` type — never throws across layers.
- Network/IO exceptions are mapped at the repository boundary.

## Build

- Gradle with the **version catalog** (`gradle/libs.versions.toml`) — add dependencies there, not inline.
- Kotlin DSL (`build.gradle.kts`).
- Run locally: `./gradlew assembleDebug`
- Unit tests: `./gradlew test`
- Instrumentation tests: `./gradlew connectedDebugAndroidTest`
- Lint + format: `./gradlew ktlintCheck detekt` (if configured)

## What Claude should do

- **Always prefer editing existing files** over creating new ones. Only create files when a new feature genuinely needs them.
- **Follow the layer boundaries.** No Android imports in `domain/`. No `Compose` imports outside `presentation/`.
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

## Useful slash commands

See `.claude/commands/`:

- `/new-feature` — scaffold a full feature (data + domain + presentation).
- `/add-screen` — add a Compose screen + ViewModel + UiState.
- `/add-usecase` — add a use case with a test.
- `/review-android` — run a review pass with `android-reviewer`.
