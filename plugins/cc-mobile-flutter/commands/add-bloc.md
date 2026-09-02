---
description: Add a Bloc (or Cubit) to an existing feature — freezed events/states, bloc_concurrency transformers, a bloc_test with state assertions.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /add-bloc $ARGUMENTS

Add a Bloc or Cubit under an existing feature. `$ARGUMENTS` is `<feature>/<Name>Bloc` (or `<Name>Cubit`).

## Before writing any code

Read `${CLAUDE_PLUGIN_ROOT}/skills/bloc-state/SKILL.md`. Decide Bloc vs Cubit. Cubit if methods map 1:1 to state transitions; Bloc if event-driven flows with concurrency concerns.

## Files to create

```
lib/feature/<feature>/presentation/bloc/<name>_bloc.dart          # or <name>_cubit.dart
lib/feature/<feature>/presentation/bloc/<name>_event.dart         # bloc only
lib/feature/<feature>/presentation/bloc/<name>_state.dart
test/feature/<feature>/bloc/<name>_bloc_test.dart
```

## State

```dart
@freezed
sealed class <Name>State with _$<Name>State {
  const factory <Name>State.idle() = _Idle;
  const factory <Name>State.loading() = _Loading;
  const factory <Name>State.success(<Payload> data) = _Success;
  const factory <Name>State.error(Failure failure) = _Error;
}
```

Use a single-state class with `status` + fields if the UI keeps its shape and only a status changes (forms are the archetype).

## Events

```dart
@freezed
sealed class <Name>Event with _$<Name>Event {
  const factory <Name>Event.loaded(String id) = _Loaded;
  const factory <Name>Event.submitted(<Form> form) = _Submitted;
}
```

## Bloc

```dart
class <Name>Bloc extends Bloc<<Name>Event, <Name>State> {
  <Name>Bloc({required this.repo, required this.logger}) : super(const <Name>State.idle()) {
    on<_Loaded>(_onLoaded, transformer: restartable());
    on<_Submitted>(_onSubmitted, transformer: droppable());
  }
  // ...
}
```

- `droppable()` for submits and other non-idempotent actions.
- `restartable()` for queries that supersede (search, filters).
- `sequential()` for ordered writes (analytics, queued uploads).
- Nothing for genuinely concurrent events (none, usually).

## Register in the feature module

```dart
sl.registerFactory<<Name>Bloc>(() => <Name>Bloc(repo: sl(), logger: sl()));
```

## Test

- One `blocTest` per event → state transition.
- One `blocTest` for the concurrency behavior if you added a transformer.
- Construct the bloc with a hand-rolled fake repo.
- Assert concrete state values; avoid `anything`.

## Codegen

Run after scaffolding:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Checklist

- [ ] Events + state are `@freezed sealed`.
- [ ] No `Equatable`.
- [ ] Transformer on any event that can be rapidly re-fired.
- [ ] Emits only within `on<...>` handlers.
- [ ] Test covers each action → state path, not just the happy one.
- [ ] No `_isProcessing` / `_inFlight` flags.
