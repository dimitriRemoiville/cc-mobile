---
description: Triage failing Android tests, cluster by root cause, delegate fixes to the android-tester subagent.
argument-hint: [--scope=:module] [--filter=TestClass]
allowed-tools: Read, Grep, Glob, Bash, Task
---

# /fix-tests

1. Run the targeted test set.
   - Default: `./gradlew :app:testDebugUnitTest --continue`.
   - If `--scope=:module` is provided, run tests in that module only.
   - If `--filter=TestClass` is provided, append `--tests "TestClass*"`.
2. Parse failures out of the Gradle output. For each, capture:
   - Fully-qualified test name.
   - Assertion / exception stack (first 5 frames).
   - File + line of the failing test.
3. Cluster failures by root cause heuristic:
   - Same exception class + same top-of-stack frame -> one cluster.
   - Same `NullPointerException` pointing at the same production file -> one cluster.
   - Unrelated assertion failures -> one cluster per test.
4. For each cluster, summarize in 1-2 sentences: what broke, who's probably at fault (production code, test, fixture, dependency).
5. Delegate the fix to the `android-tester` subagent via the Task tool:
   - Pass the cluster summary.
   - Pass the file paths of both production code and test.
   - Ask the subagent to make the smallest change that turns all tests in the cluster green.
6. After each subagent returns, re-run the scoped tests once. Stop clustering when the first cluster re-runs green.
7. Final output: which clusters were fixed, which remain, and any tests that look intentionally broken (`@Ignore`, TODO) that the user should triage manually.

Do not bulk-update snapshots or "expected" constants — that's a deliberate choice the user makes. Flag instead.
