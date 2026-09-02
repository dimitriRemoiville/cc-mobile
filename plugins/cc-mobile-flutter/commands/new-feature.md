---
description: Scaffold a new feature in lib/feature/ with data + domain + presentation, a GetIt module, and a typed go_router route.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /new-feature $ARGUMENTS

Scaffold a new feature. `$ARGUMENTS` is the feature name in `snake_case` (e.g. `order_detail`, `wishlist`). If empty, ask.

## Before writing any code

Read:
- `${CLAUDE_PLUGIN_ROOT}/skills/flutter-architecture/SKILL.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/bloc-state/SKILL.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/get-it-di/SKILL.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/widgets-and-screens/SKILL.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/dio-networking/SKILL.md` (if the feature hits the API)

Confirm with the user: does this feature need local persistence (drift)? Any existing repository it depends on?

## Layout to create

```
lib/feature/<feature>/
├── di/<feature>_module.dart
├── data/
│   ├── mappers/<feature>_mapper.dart
│   └── repositories/<feature>_repository_impl.dart
├── domain/
│   ├── entities/<feature>.dart                      # @freezed
│   └── repositories/<feature>_repository.dart       # abstract interface
└── presentation/
    ├── bloc/
    │   ├── <feature>_bloc.dart
    │   ├── <feature>_event.dart                     # @freezed sealed
    │   └── <feature>_state.dart                     # @freezed sealed
    ├── pages/<feature>_page.dart                    # BlocProvider + listeners
    └── widgets/<feature>_view.dart                  # stateless, testable
```

Tests (mirror under `test/feature/<feature>/`):

```
test/feature/<feature>/
├── bloc/<feature>_bloc_test.dart
├── data/<feature>_repository_impl_test.dart
└── presentation/<feature>_view_test.dart
```

## Wire-up

1. Call `register<Feature>Module(sl)` from `core/di/container.dart` inside `initializeDependencies()`.
2. Add a typed route in `lib/routing/` with `@TypedGoRoute<<Feature>Route>(...)`.
3. Run `dart run build_runner build --delete-conflicting-outputs` to generate freezed + go_router_builder outputs.

## Checklist before you call it done

- [ ] `presentation/` has zero imports from `data/` or the generated API client.
- [ ] Repository returns `Future<Either<Failure, T>>`; mixin `ApiCallErrorHandling` if it hits the API.
- [ ] Bloc events use a `bloc_concurrency` transformer (`droppable` / `restartable` / `sequential`) unless genuinely concurrent.
- [ ] Route reachable from an existing screen (don't orphan it).
- [ ] At least one bloc test, one repository test, one widget test.
- [ ] `dart analyze --fatal-infos --fatal-warnings` passes.
