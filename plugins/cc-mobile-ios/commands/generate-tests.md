---
description: Generate missing tests for existing Swift/iOS code — ViewModels, use cases, repositories, mappers, and SwiftUI views.
argument-hint: "[--feature=<feature>] [--file=<path>] [--diff=main]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /generate-tests

Generate tests for existing code that doesn't have them yet.

## Targeting

Exactly one of:

| Flag | Scope |
|---|---|
| `--feature=<feature>` | All testable types in the `<feature>/` group (use case, view model, repository, mapper). |
| `--file=<path>` | A single production file. |
| `--diff=<base>` | Every changed file vs `<base>` (default: `main`). Only Swift files under the main app target. |
| *(none)* | Same as `--diff=main`. |

## Procedure

1. **Load context.** Read `${CLAUDE_PLUGIN_ROOT}/skills/ios-testing/SKILL.md` and `${CLAUDE_PLUGIN_ROOT}/skills/swift-style/SKILL.md`.

2. **Discover targets.**
   - `--feature`: glob for Swift files under the feature directory. Filter to testable types (see classification below).
   - `--file`: use as-is.
   - `--diff`: run `git diff --name-only --diff-filter=ACMR <base>...HEAD -- '*.swift'`. Exclude `Tests/`, `UITests/`, generated files, and package manifests.

3. **Filter out already-tested files.** For each candidate, check whether a corresponding test file already exists:
   - `FooViewModel.swift` → look for `FooViewModelTests.swift` in `Tests/`.
   - If a test exists, skip the file unless it has 0 `@Test` functions (empty shell).

4. **Classify each target** and decide the test shape:

   | Type | Detection heuristic | Test shape |
   |---|---|---|
   | **ViewModel** | Conforms to `ObservableObject` or uses `@Observable`, has `@MainActor` | `@Suite @MainActor` struct. Assert state transitions. Cover initial state, happy path, one error path. |
   | **UseCase** | Lives in `Domain/UseCases/`, has a `callAsFunction` or `execute` method | Stub repository. `async throws`. Happy path + one failure path with `#expect(throws:)`. |
   | **Repository impl** | Implements a domain repository protocol | `MockURLProtocol`-based. Happy path + error mapping (401/404/5xx → domain error). |
   | **Mapper / extension** | Top-level function or extension doing DTO→domain or domain→presentation mapping | Pure data-in / data-out. No fakes. |
   | **SwiftUI View** | Struct conforming to `View` | Skip by default — views are tested via ViewModel tests + previews. Only generate a UI test (`UITests/`) if the user explicitly passes `--file=` targeting a view. |

   Skip: route definitions, DI registration, `@Serializable` model-only files (no logic), `App.swift`, generated code.

5. **Generate tests.** For each target, delegate to the `ios-tester` subagent via the Task tool:
   - Pass: the production file path, its classification, the test shape from the table above, and any domain types it references.
   - The subagent writes the test file under `Tests/`, following `ios-testing` skill conventions (Swift Testing `@Test` / `#expect`).
   - Group by feature so the subagent gets sibling context.

6. **Run tests.**
   - `xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing '<TestTarget>/<TestSuite>'` for each generated test.
   - If no simulator is available, attempt `swift test` for pure-Swift targets. If neither works, report the tests as ready-to-run.
   - If a test fails, the subagent fixes it in the same delegation (up to 2 retries). If it still fails after retries, drop the test and report the failure.

7. **Report.**
   - List each generated test file with a one-line summary of what it covers.
   - List any targets that were skipped and why (already tested, not classifiable, test failed after retries).
   - Print the final `xcodebuild test` command to re-run all generated tests at once.

## Hard rules

- **Follow existing test conventions.** If the project already has tests, match their style (Swift Testing vs XCTest, naming, helper patterns). Don't introduce a new testing pattern.
- **Swift Testing by default.** Use `@Test`, `@Suite`, `#expect`, `#require` — not `XCTestCase` — unless the existing test suite is XCTest-based.
- **No test without a run.** Every generated test must pass before reporting success (unless no simulator is available — then report as ready-to-run).
- **Hand-rolled fakes over mocking frameworks.** Define protocol-conforming stubs inline or in a shared `Helpers/` directory. No third-party mocking library.
- **No `.disabled()` or `XCTSkip` tests.** Either the test works or it doesn't get committed.
- **No real IO.** No real URLSession (use `MockURLProtocol`), no real file system, no `Task.sleep` in assertions.
- **`@MainActor` on ViewModel test suites.** Required for `@Observable` / `@ObservableObject` state access.
