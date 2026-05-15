---
description: Generate missing tests for existing shared Kotlin Multiplatform code — ViewModels, use cases, Ktor repositories, and mappers.
argument-hint: "[--feature=<feature>] [--file=<path>] [--diff=main]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /generate-tests

Generate tests for existing shared KMP code that doesn't have them yet.

## Targeting

Exactly one of:

| Flag | Scope |
|---|---|
| `--feature=<feature>` | All testable classes in the `<feature>/` package under `shared/src/commonMain/`. |
| `--file=<path>` | A single production file. |
| `--diff=<base>` | Every changed file vs `<base>` (default: `main`). Only Kotlin files under `shared/src/commonMain/`. |
| *(none)* | Same as `--diff=main`. |

## Procedure

1. **Load context.** Read `.claude/skills/kmm-testing/SKILL.md`.

2. **Discover targets.**
   - `--feature`: glob `shared/src/commonMain/kotlin/**/<feature>/**/*.kt`. Filter to testable types (see classification below).
   - `--file`: use as-is.
   - `--diff`: run `git diff --name-only --diff-filter=ACMR <base>...HEAD -- 'shared/src/commonMain/**.kt'`. Filter to testable types.

3. **Filter out already-tested files.** For each candidate, check whether a corresponding test file already exists:
   - `FooUseCase.kt` → look for `FooUseCaseTest.kt` in `shared/src/commonTest/`.
   - Mirror the `commonMain/kotlin/` path into `commonTest/kotlin/`, append `Test` to the class name.
   - If a test exists, skip the file unless it has 0 `@Test` functions (empty shell).

4. **Classify each target** and decide the test shape:

   | Type | Detection heuristic | Test shape |
   |---|---|---|
   | **ViewModel** | Extends the shared ViewModel base, exposes `StateFlow` | `StandardTestDispatcher`, `Dispatchers.setMain()`, `advanceUntilIdle()`. Assert state transitions. Cover initial → success + one error path. |
   | **UseCase** | Lives in `domain/usecase/`, has `suspend operator fun invoke` or `suspend fun execute` | `runTest { }`, hand-rolled fake repository. Happy path + one failure path. |
   | **Ktor Repository** | Implements a domain repository interface, uses `HttpClient` | `MockEngine`-based. Assert request path/method/body. Script success + error responses. |
   | **Mapper / extension** | Top-level or extension function doing DTO→domain mapping | Pure data-in / data-out. No fakes. |

   Skip: `expect`/`actual` declarations (test the `actual` via platform tests if needed), DI modules (Koin module tests are optional), `@Serializable` model-only files (no logic), route definitions.

5. **Generate tests.** For each target, delegate to the `kmm-tester` subagent via the Task tool:
   - Pass: the production file path, its classification, the test shape from the table above, and any domain types it references.
   - The subagent writes the test file under `shared/src/commonTest/`, following `kmm-testing` skill conventions (`kotlin.test` + `kotlinx-coroutines-test`).
   - Group by feature so the subagent gets sibling context.
   - **`commonTest` first.** Only put tests in `androidUnitTest` or `iosTest` when the code under test is platform-specific (`actual` declarations, Android/iOS-only APIs).

6. **Run tests.**
   - `./gradlew :shared:allTests --tests '*<TestClass>'` for each generated test.
   - If iOS simulator is unavailable, fall back to `./gradlew :shared:jvmTest` and note that iOS target tests are ready-to-run.
   - If a test fails, the subagent fixes it in the same delegation (up to 2 retries). If it still fails after retries, drop the test and report the failure.

7. **Report.**
   - List each generated test file with a one-line summary of what it covers.
   - List any targets that were skipped and why (already tested, not classifiable, test failed after retries).
   - Print the final `./gradlew` command to re-run all generated tests at once.

## Hard rules

- **Follow existing test conventions.** If the project already has tests, match their style (assertion library, naming, coroutine setup). Don't introduce a new testing pattern.
- **`commonTest` by default.** Only use `androidUnitTest` or `iosTest` for platform-specific code. No JUnit imports in `commonTest` — use `kotlin.test` assertions.
- **No test without a run.** Every generated test must pass before reporting success.
- **Hand-rolled fakes in `commonTest`.** No MockK in `commonTest` (it's JVM-only). Use MockK only in `androidUnitTest`. For `commonTest`, define interface-conforming fakes inline.
- **No `@Ignore` or `@IgnoreIos` tests.** Either the test works or it doesn't get committed.
- **No real IO.** No real Ktor `HttpClient` (use `MockEngine`), no `runBlocking`, no `Thread.sleep`.
- **Ktor `MockEngine` tests assert the request.** Don't just script a response — verify path, method, and body.
