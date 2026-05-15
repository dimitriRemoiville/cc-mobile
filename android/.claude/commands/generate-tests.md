---
description: Generate missing tests for existing Android code — ViewModels, use cases, mappers, repositories, and Compose screens.
argument-hint: "[--feature=<feature>] [--file=<path>] [--diff=main]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /generate-tests

Generate tests for existing code that doesn't have them yet.

## Targeting

Exactly one of:

| Flag | Scope |
|---|---|
| `--feature=<feature>` | All testable classes in `<feature>/` (use case, VM, mapper, screen). |
| `--file=<path>` | A single production file. |
| `--diff=<base>` | Every changed file vs `<base>` (default: `main`). Only Kotlin files under `app/src/main/`. |
| *(none)* | Same as `--diff=main`. |

## Procedure

1. **Load context.** Read `.claude/skills/android-testing/SKILL.md` and `.claude/skills/kotlin-style/SKILL.md`.

2. **Discover targets.**
   - `--feature`: glob `app/src/main/java/**/<feature>/**/*.kt`. Filter to testable types (see classification below).
   - `--file`: use as-is.
   - `--diff`: run `git diff --name-only --diff-filter=ACMR <base>...HEAD -- 'app/src/main/java/**.kt'`. Filter to testable types.

3. **Filter out already-tested files.** For each candidate, check whether a corresponding test file already exists:
   - `Foo.kt` → look for `FooTest.kt` in `src/test/` or `src/androidTest/`.
   - If a test exists, skip the file unless it has 0 `@Test` methods (empty shell).

4. **Classify each target** and decide the test shape:

   | Type | Detection heuristic | Test shape |
   |---|---|---|
   | **ViewModel** | Extends `ViewModel`, has `@HiltViewModel` | State-flow test with Turbine. Mock use cases + `AnalyticsTracker`. Assert `init { }` analytics event. Cover Loading → Success + one error path. |
   | **UseCase** | Lives in `domain/usecase/`, has `operator fun invoke` | Mock repository. Happy path + one `Outcome.Failure` path. |
   | **Repository impl** | Implements a `domain/repository/` interface | Mock the API / DAO / remote data source. Happy path + network-error path mapped to `DomainError`. |
   | **Mapper / extension** | Top-level or companion `fun` doing DTO→domain or domain→UI mapping | Pure data-in / data-out. No mocks. |
   | **Compose Screen** | `@Composable fun <Name>Screen(...)` (stateless) | Compose UI test via `createComposeRule()`. Render with sample state, assert key nodes. Goes in `src/androidTest/`. |

   Skip: `Route.kt` (no logic), DI modules (Hilt generates tests), `@Serializable data object` route markers, `Application` subclass.

5. **Generate tests.** For each target, delegate to the `android-tester` subagent via the Task tool:
   - Pass: the production file path, its classification, the test shape from the table above, and any domain types it references (so the subagent can build realistic fixtures).
   - The subagent writes the test file, following `android-testing` skill conventions.
   - Group by feature so the subagent gets sibling context (e.g., a feature's ViewModel + UseCase + Screen in one delegation rather than three).

6. **Run tests.**
   - Unit tests: `./gradlew :app:testDebugUnitTest --tests '*<TestClass>'` for each generated test.
   - Compose UI tests: report them as ready-to-run (`connectedDebugAndroidTest`) — don't block on emulator availability.
   - If a test fails, the subagent fixes it in the same delegation (up to 2 retries). If it still fails after retries, drop the test and report the failure — don't ship a broken test.

7. **Report.**
   - List each generated test file with a one-line summary of what it covers.
   - List any targets that were skipped and why (already tested, not classifiable, test failed after retries).
   - Print the final `./gradlew` command to re-run all generated tests at once.

## Hard rules

- **Follow existing test conventions.** If the project already has tests, match their style (assertion library, naming, structure). Don't introduce a new testing pattern.
- **No test without a run.** Every generated unit test must pass before reporting success.
- **No mocking domain models.** Use real `data class` instances. Mock only framework boundaries (Retrofit services, DAOs, `AnalyticsTracker`).
- **No `@Ignore` or `TODO` tests.** Either the test works or it doesn't get committed.
- **Fakes vs mocks.** Default to fakes for interfaces with >2 methods; mock single-method collaborators and generated services (per `android-testing` skill).
