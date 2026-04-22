---
description: Triage failing iOS tests, cluster by root cause, delegate fixes to the ios-tester subagent.
argument-hint: [--scheme=App] [--filter=TestClass/test_method]
allowed-tools: Read, Grep, Glob, Bash, Task
---

# /fix-tests

1. Run the targeted test set.
   - Default: `xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=iPhone 15' -enableCodeCoverage NO -quiet`.
   - If `--scheme=Foo` provided, swap the scheme.
   - If `--filter=TestClass/test_method` provided, append `-only-testing:<scheme>Tests/<filter>`.
2. Parse failures from the xcodebuild output (both XCTest and Swift Testing style). For each:
   - Test identifier.
   - First failing `#expect`/`XCTAssert` message.
   - File + line of the failure.
   - File + line of the production code referenced in the top stack frame (if any).
3. Cluster failures:
   - Same failing `#expect` in multiple tests against the same type -> one cluster.
   - Same top-of-stack production file -> one cluster.
   - Swift 6 concurrency diagnostics (`Sending 'x' risks causing data races`) bucketed separately; those are usually not test bugs but production code changes.
4. For each cluster, summarize: what broke, likely culprit.
5. Delegate to `ios-tester` via Task tool. Pass cluster summary + test and prod file paths. Ask for the minimum-diff fix.
6. Re-run the scoped tests after each subagent returns. Stop clustering once green.
7. Final output: fixed clusters, remaining clusters, any `.disabled()` / `XCTSkip` cases flagged for manual review.

Don't silently update inline snapshots or fixtures; flag and let the user decide.
