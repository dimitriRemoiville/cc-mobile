---
description: Scaffold a full feature (data + domain + presentation) following the project's Clean Architecture conventions.
argument-hint: <feature-name> [--screen=<ScreenName>]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

You are scaffolding a new feature called **$ARGUMENTS**.

Follow this sequence — do not skip steps:

1. **Load context.** Read `CLAUDE.md` and skim `.claude/skills/android-architecture/SKILL.md`, `.claude/skills/hilt-di/SKILL.md`, and `.claude/skills/compose-ui/SKILL.md`.
2. **Scan the existing codebase** for the nearest similar feature. Match its package structure, naming, and module conventions. Do not introduce a new pattern unless there's a clear reason.
3. **Produce a short plan** (5–10 lines) listing every file you'll create or touch. Confirm with the user before writing if the plan introduces new modules or changes build files.
4. **Generate the feature** with this structure (adjust names):

   ```
   <feature>/
   ├── data/
   │   ├── remote/<Feature>Api.kt            # Retrofit
   │   ├── remote/<Feature>Dto.kt            # DTOs
   │   ├── mapper/<Feature>Mapper.kt
   │   ├── repository/<Feature>RepositoryImpl.kt
   │   └── di/<Feature>DataModule.kt         # Hilt module
   ├── domain/
   │   ├── model/<Feature>.kt
   │   ├── repository/<Feature>Repository.kt
   │   └── usecase/Get<Feature>UseCase.kt
   └── presentation/
       ├── <Feature>UiState.kt
       ├── <Feature>Action.kt
       ├── <Feature>Event.kt
       ├── <Feature>ViewModel.kt
       ├── <Feature>Screen.kt                # stateless + Route wrapper
       └── navigation/<Feature>NavGraph.kt
   ```

5. **Wire navigation** — add the destination to the app's NavGraph. Don't leave the screen unreachable.
6. **Tests.** Create at least:
   - Unit test for the use case.
   - Unit test for the mapper.
   - ViewModel test covering Loading → Success and an error path.
   - Compose UI test for the Screen's happy path.

   Use the `android-tester` subagent via the Task tool if the test suite is non-trivial.

7. **Verify** the build compiles: `./gradlew :app:assembleDebug` and the unit tests pass: `./gradlew :app:testDebugUnitTest`.

8. **Report** what was created, link each file, and list any TODOs you left behind.

Hard rules:
- No `androidx.*`, `retrofit2.*`, or `androidx.room.*` imports in `domain/`.
- No Compose imports outside `presentation/`.
- All new dependencies go in the version catalog.
- Every new Composable has at least one `@Preview`.
