---
description: Generate missing tests for existing Flutter code — Blocs, repositories, widgets, use cases, and mappers.
argument-hint: "[--feature=<feature>] [--file=<path>] [--diff=main]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /generate-tests

Generate tests for existing code that doesn't have them yet.

## Targeting

Exactly one of:

| Flag | Scope |
|---|---|
| `--feature=<feature>` | All testable classes in `lib/features/<feature>/` (bloc, repository, widget, use case). |
| `--file=<path>` | A single production file. |
| `--diff=<base>` | Every changed file vs `<base>` (default: `main`). Only Dart files under `lib/`. |
| *(none)* | Same as `--diff=main`. |

## Procedure

1. **Load context.** Read `.claude/skills/flutter-testing/SKILL.md` and `.claude/skills/dart-style/SKILL.md`.

2. **Discover targets.**
   - `--feature`: glob `lib/features/<feature>/**/*.dart`. Filter to testable types (see classification below).
   - `--file`: use as-is.
   - `--diff`: run `git diff --name-only --diff-filter=ACMR <base>...HEAD -- 'lib/**.dart'`. Filter to testable types.

3. **Filter out already-tested files.** For each candidate, check whether a corresponding test file already exists:
   - `lib/features/foo/bloc/foo_bloc.dart` → look for `test/features/foo/bloc/foo_bloc_test.dart`.
   - Mirror the `lib/` path into `test/`, append `_test.dart`.
   - If a test exists, skip the file unless it has 0 `test(` or `blocTest(` calls (empty shell).

4. **Classify each target** and decide the test shape:

   | Type | Detection heuristic | Test shape |
   |---|---|---|
   | **Bloc / Cubit** | Extends `Bloc<E, S>` or `Cubit<S>` | `blocTest<B, S>(...)` with hand-rolled fakes. Cover initial state, happy-path event → states, one error path. |
   | **UseCase** | Lives in `domain/usecase/`, has `call()` method | Mock repository. Happy path + one failure path. |
   | **Repository impl** | Implements a domain repository interface | Mock the generated API client (not Dio). Happy path + error mapping (401/404/5xx). |
   | **Mapper / extension** | Top-level or extension function doing DTO→domain or domain→presentation mapping | Pure data-in / data-out. No mocks. |
   | **Widget / Screen** | Widget class with `build()` method, lives in `presentation/` | Widget test via `pumpApp()` helper. Fake the bloc, render, assert key finders. |

   Skip: route configuration, DI registration (`injection.dart`), generated files (`*.g.dart`, `*.freezed.dart`), barrel exports.

5. **Generate tests.** For each target, delegate to the `flutter-tester` subagent via the Task tool:
   - Pass: the production file path, its classification, the test shape from the table above, and any domain types it references.
   - The subagent writes the test file, following `flutter-testing` skill conventions.
   - Group by feature so the subagent gets sibling context.

6. **Run tests.**
   - `flutter test test/features/<feature>/<layer>/<name>_test.dart` for each generated test.
   - If a test fails, the subagent fixes it in the same delegation (up to 2 retries). If it still fails after retries, drop the test and report the failure.

7. **Report.**
   - List each generated test file with a one-line summary of what it covers.
   - List any targets that were skipped and why (already tested, not classifiable, test failed after retries).
   - Print the final `flutter test` command to re-run all generated tests at once.

## Hard rules

- **Follow existing test conventions.** If the project already has tests, match their style (mocktail vs hand-rolled fakes, naming, helpers in `test/helpers/`). Don't introduce a new testing pattern.
- **No test without a run.** Every generated test must pass before reporting success.
- **Hand-rolled fakes over mocks** for classes with >2 methods. Mock only generated API clients, single-method collaborators, and leaf services (per `flutter-testing` skill).
- **No `skip:` or `// TODO` tests.** Either the test works or it doesn't get committed.
- **No real IO.** No real Dio, no real file system, no `Future.delayed` outside `fakeAsync`.
- **GetIt scoping.** Use `pushNewScope`/`popScope` in test setup/teardown — never `allowReassignment`.
