---
description: Scaffold a full feature (data + domain + presentation) following the project's Clean Architecture conventions.
argument-hint: <feature-name> [--screen=<ScreenName>]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

You are scaffolding a new feature called **$ARGUMENTS**.

Follow this sequence — do not skip steps:

1. **Load context.** Read `CLAUDE.md` and skim `.claude/skills/android-architecture/SKILL.md`, `.claude/skills/android-app-skeleton/SKILL.md` (the canonical feature shape lives there), `.claude/skills/hilt-di/SKILL.md`, `.claude/skills/retrofit-networking/SKILL.md`, and `.claude/skills/compose-ui/SKILL.md`.
2. **Scan the existing codebase** for the nearest similar feature. Match its package structure, naming, and module conventions. Do not introduce a new pattern unless there's a clear reason.
3. **Produce a short plan** (5–10 lines) listing every file you'll create or touch. Confirm with the user before writing if the plan introduces new modules or changes build files.
4. **Generate the feature** with this **feature-first** structure (per `android-architecture` and `android-app-skeleton`; layer-first packaging is rejected here on purpose):

   ```
   <feature>/
   ├── data/
   │   ├── remote/<Feature>Api.kt              # Retrofit interface
   │   ├── remote/<Feature>Dto.kt              # DTOs (mapping fn colocated with the DTO)
   │   ├── repository/<Feature>RepositoryImpl.kt
   │   └── di/<Feature>DataModule.kt           # Hilt module
   ├── domain/
   │   ├── model/<Feature>.kt
   │   ├── repository/<Feature>Repository.kt   # interface; returns Outcome<T>
   │   └── usecase/Get<Feature>UseCase.kt      # operator suspend fun invoke(...): Outcome<...>
   └── ui/
       ├── <Feature>UiState.kt
       ├── <Feature>Event.kt                   # one-shot effects via Channel (navigation, snackbar) — keep only if the screen needs them
       ├── <Feature>ViewModel.kt
       ├── <Feature>Screen.kt                  # stateless Screen + Route wrapper + Preview(s)
       └── <Feature>Route.kt                   # @Serializable destination (one file per feature)
   ```

   Promote `data/mapper/` to its own package only when several DTOs map to the same domain type — otherwise keep mapping functions colocated with the DTO. Use `core/data/network/Outcomes.kt` (`toOutcome` + `toDomainError`) for the `Result → Outcome` conversion in the repository implementation; never open-code `runCatching { ... }.fold(...)` (it swallows `CancellationException`).

   The `<Feature>ViewModel` exposes **discrete public functions** for user actions (`fun retry()`, `fun submit(...)`); the Composable takes one lambda per action (`onRetry: () -> Unit`). Matches Google's [Now in Android](https://github.com/android/nowinandroid) and the official MVVM guidance. Escalate to a sealed `<Feature>Action.kt` + a single `onAction: (Action) -> Unit` callback only when the screen has ≥5 distinct interactions and the Composable signature would otherwise balloon (that's an MVI shape; this project is MVVM by default).

   The `<Feature>ViewModel` injects `AnalyticsTracker` as a `private val` and fires the screen-viewed event from `init { }` — same shape as `feed/ui/FeedViewModel.kt` in the scaffold.

5. **Wire navigation** — register the feature's `@Serializable` route in `core/navigation/AppNavGraph.kt`. Don't leave the screen unreachable.
6. **Tests.** Create at least:
   - Unit test for the use case (happy path + one error path returning `Outcome.Failure(DomainError.X())`).
   - Unit test for the mapper (only if extracted into its own function — inline maps don't need standalone tests).
   - ViewModel test covering Loading → Success and an error path.
   - Compose UI test for the Screen's happy path.

   Use the `android-tester` subagent via the Task tool if the test suite is non-trivial.

7. **Verify** the build compiles: `./gradlew :app:assembleDebug` and the unit tests pass: `./gradlew :app:testDebugUnitTest`.

8. **Report** what was created, link each file, and list any TODOs you left behind.

Hard rules:
- **Domain-facing return types are `Outcome<T>`.** No `Result<T>` on a `domain/` interface, no raw throws across a layer boundary. `Result<T>` is allowed *inside* `<feature>/data/` as scratch (`runCatching { ... }.toOutcome(::toDomainError)`); flag it anywhere else.
- **No `androidx.*`, `retrofit2.*`, or `androidx.room.*` imports** in `<feature>/domain/` or `core/domain/`.
- **No Compose imports outside `ui/` packages** (`<feature>/ui/` or `core/ui/`).
- **All new dependencies go in the version catalog.**
- **Every new Composable has at least one `@Preview`** wrapped in `AppTheme`.
