---
description: Triage failing Flutter tests, cluster by root cause, delegate fixes to the flutter-tester subagent.
argument-hint: [--scope=test/path] [--filter=TestName]
allowed-tools: Read, Grep, Glob, Bash, Task
---

# /fix-tests

1. Run the targeted test set:
   - Default: `flutter test --reporter=expanded`.
   - If `--scope=test/foo_test.dart` provided, run just that file.
   - If `--filter=name` provided, append `--plain-name "name"`.
2. Parse failures. For each capture:
   - Test description.
   - First failing `expect`.
   - File + line in the test.
   - File + line of production code in the stack (if any).
3. Cluster:
   - Same matcher failure against the same bloc state type -> one cluster.
   - Same exception at the same production line -> one cluster.
   - Goldens diffs -> always a separate cluster; never auto-regenerate without asking.
   - Async gap / pending timer issues (`pumpAndSettle` timeouts, unawaited futures) -> separate cluster.
4. Summarize each cluster: what broke, likely culprit (production, test setup, mock behaviour, golden).
5. Delegate to `flutter-tester` via Task tool with cluster summary and relevant file paths. Ask for the minimum-diff fix.
6. Re-run the scoped tests after each subagent returns. Stop when green.
7. Final output: fixed clusters, remaining clusters, `skip:` / `@Skip` tests flagged for manual review.

Never run `flutter test --update-goldens` as part of this command. Flag the failing golden and let the user decide.
