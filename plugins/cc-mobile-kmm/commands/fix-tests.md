---
description: Triage failing KMP tests (common, android, iosX64), cluster by target + root cause, delegate to kmm-tester.
argument-hint: [--target=common|android|ios] [--filter=TestClass]
allowed-tools: Read, Grep, Glob, Bash, Task
---

# /fix-tests

1. Run the targeted tests:
   - Default: `./gradlew :shared:allTests`.
   - `--target=common` -> `./gradlew :shared:jvmTest` (for JVM-backed `commonTest`).
   - `--target=android` -> `./gradlew :shared:testDebugUnitTest :androidApp:testDebugUnitTest`.
   - `--target=ios` -> `./gradlew :shared:iosSimulatorArm64Test` (or `iosX64Test` on Intel).
   - If `--filter=TestClass` provided, append `--tests "TestClass*"`.
2. Parse failures per target. Tag each failure with its target — the same test can fail only on iOS due to `expect/actual` drift or Ktor engine differences.
3. Cluster heuristics:
   - Same exception + same file across multiple targets -> one cluster, likely `commonMain`.
   - Same test passing on Android but failing on iOS -> one cluster, likely `expect/actual` or Darwin-specific Ktor engine.
   - Coroutines test timeouts (`TimeoutCancellationException`) -> cluster separately, usually `runTest` vs real time.
4. Summarize each cluster: what broke, which target, likely culprit (`commonMain`, `androidMain`, `iosMain`, test fixture, dependency).
5. Delegate to `kmm-tester` via Task tool. Provide the cluster, the failing targets, the file paths for both production (`:shared/src/<target>Main`) and test (`:shared/src/<target>Test`).
6. Re-run the scoped target after each subagent returns. Stop once green.
7. Final output: fixed clusters, remaining clusters, tests disabled with `@Ignore` / `@IgnoreIos` flagged for manual review.

Don't mute targets to get green. If only one target fails, that's usually a real bug, not a test bug.
