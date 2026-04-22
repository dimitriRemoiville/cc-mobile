---
description: Review the current changes against KMM conventions, source-set discipline, and iOS interop rules.
allowed-tools: Read, Grep, Glob, Bash, Task
---

# /review-kmm

Delegate a review of the in-progress work to the `kmm-reviewer` subagent. The reviewer focuses on:

- Source-set discipline — no Android/iOS types leaking into `commonMain`.
- Layer boundaries — `presentation → domain ← data`, never crossing.
- iOS interop hygiene — no `inline` on public API, no default arguments, shallow sealed hierarchies, `@Throws` on throwing suspends, no `internal` types leaking.
- Ktor usage — no engine type references in `commonMain`, error mapping at the repository boundary, `CancellationException` rethrown.
- Koin wiring — modules registered in `initKoin(...)`, platform bindings in platform modules.
- Tests — living under `commonTest` by default, `runTest` everywhere, no `MockK`/JUnit in common.

## How to invoke

Use the Task tool with `subagent_type: "kmm-reviewer"`. Pass the review target as context (the file list from `git status` or the specific paths changed).

Produce a short, action-oriented review — no restatement of what the code does, just what needs to change.
