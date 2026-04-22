---
description: Delegate a focused review of the current changes to the flutter-reviewer subagent.
allowed-tools: Read, Grep, Glob, Bash, Task
---

# /review-flutter

Run the `flutter-reviewer` subagent against the current working changes. The reviewer focuses on:

- Layer boundaries (no dio / drift / generated DTOs in `presentation/`).
- Repository contract (`Future<Either<Failure, T>>`, `CancelledFailure` rethrown).
- Bloc hygiene (freezed states/events, `bloc_concurrency` transformers, no manual `_isProcessing`).
- Widget discipline (stateless views, `const` constructors, no `GetIt` in `build`, typed `go_router`).
- Async & null (`unawaited`, `!mounted` guards after `await`, minimal `!` operator use).
- Tests (`mocktail` not `mockito`, concrete assertions, GetIt scopes not `allowReassignment`).

## How to invoke

Use the Task tool with `subagent_type: "flutter-reviewer"`. Pass the diff / file list from `git status --short` as context.

Produce a numbered, action-oriented list. No restating what the code does.
