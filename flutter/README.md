# Flutter Claude Code setup

Opinionated Claude Code configuration for a Flutter app using Clean Architecture + flutter_bloc + typed go_router + get_it + dio + drift.

This setup is informed by the `bdi-interventions-app` codebase — it keeps the conventions that are working (Clean Architecture, feature-level DI modules, `Either<Failure, T>` at the repository boundary, drift + sqlcipher, an OpenAPI-generated API client) and updates the ones that have aged (freezed over Equatable, fpdart over dartz, typed routes over enums, `bloc_concurrency` over manual flags, mocktail over mockito).

## Stack

- **Language & framework:** Dart 3 + Flutter 3.35+.
- **State:** `flutter_bloc` + `formz` + `bloc_concurrency`.
- **Routing:** `go_router` with **typed routes** via `go_router_builder`.
- **DI:** `get_it` with per-feature modules and scopes.
- **Networking:** `dio` behind an OpenAPI-generated client package.
- **Error model:** `fpdart` + a sealed `Failure` hierarchy.
- **Immutability & codegen:** `freezed` (states, entities, unions) + `json_serializable` (hand-rolled DTOs, if any).
- **Persistence:** `drift` + `sqlcipher_flutter_libs`, `shared_preferences`, `flutter_secure_storage`.
- **Observability:** Firebase Crashlytics + Analytics + Remote Config behind thin service interfaces.
- **Testing:** `flutter_test` + `bloc_test` + `mocktail`; `alchemist` (or `golden_toolkit`) for goldens.

## Layout

```
flutter/
├── CLAUDE.md                          # always-loaded project context
├── README.md                          # this file
└── .claude/
    ├── settings.json                  # flutter/dart/xcode/gradle/git permissions
    ├── agents/
    │   ├── flutter-architect.md       # architectural decisions
    │   ├── flutter-ui-engineer.md     # screens + widgets + typed routes
    │   ├── flutter-reviewer.md         # idiom + layer + bloc + async review
    │   ├── flutter-tester.md           # unit / bloc / widget / golden tests
    │   └── flutter-build-expert.md     # pubspec, build_runner, lints, flavors
    ├── skills/
    │   ├── flutter-architecture/SKILL.md
    │   ├── dart-style/SKILL.md
    │   ├── widgets-and-screens/SKILL.md
    │   ├── bloc-state/SKILL.md
    │   ├── get-it-di/SKILL.md
    │   ├── dio-networking/SKILL.md
    │   ├── drift-persistence/SKILL.md
    │   ├── flutter-testing/SKILL.md
    │   └── flutter-app-skeleton/SKILL.md
    └── commands/
        ├── init-flutter-app.md
        ├── new-feature.md
        ├── add-screen.md
        ├── add-bloc.md
        ├── add-usecase.md
        └── review-flutter.md
```

## Conventions at a glance

- `presentation → domain ← data` per feature. Nothing from `data/` or the generated API client leaks into `presentation/`.
- One `Dio` per app. Repositories depend on the generated API client, not on `Dio`.
- Repositories return `Future<Either<Failure, T>>`. Errors map to a **sealed `Failure`** in the repository via `ApiCallErrorHandling`.
- `@freezed sealed` for states, events, and entities. No `Equatable` in new code.
- Bloc events that can be spam-fired use `bloc_concurrency` transformers (`droppable`, `restartable`, `sequential`) — no manual `_isProcessing` flags.
- Every routable screen is a **`<Feature>Page`** (BlocProvider + listeners) + **`<Feature>View`** (stateless, testable).
- `go_router_builder` typed routes. No string path enums.
- `get_it` uses feature-level modules; tests use `pushNewScope` — never `allowReassignment = true`.
- `mocktail` only. `mockito` is not used.

## Slash commands

- `/init-flutter-app [name]` — scaffold a brand-new Flutter app from scratch (folders, `pubspec.yaml`, analysis options, core/, routing, shared/, splash route, tests). Asks about flavors, drift, Firebase, notifications, and workmanager up front. Backed by the `flutter-app-skeleton` skill.
- `/new-feature <name>` — scaffold a full feature (data + domain + presentation + module + route).
- `/add-screen <feature>/<Name>` — add a page + view + typed route.
- `/add-bloc <feature>/<Name>` — add a bloc (or cubit) with freezed states/events.
- `/add-usecase <feature>/<Name>` — add a domain use case (only when it earns its keep).
- `/review-flutter` — delegate a review to the `flutter-reviewer` subagent.

## Build and test

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --flavor dev  --target lib/main_dev.dart
flutter run --flavor prod --target lib/main_prod.dart

flutter test
flutter test --update-goldens
dart analyze --fatal-infos --fatal-warnings
dart format --set-exit-if-changed .
```

## Why these choices over common alternatives

- **freezed over Equatable** — generated `copyWith`, exhaustive `.map` / pattern matching, union types with one annotation. Less boilerplate, safer refactors.
- **fpdart over dartz** — `dartz` is effectively unmaintained; `fpdart` is the active replacement with Dart 3–friendly ergonomics.
- **Typed go_router over string enums** — compile-time safety on route params. Typos fail to build instead of failing at runtime.
- **`bloc_concurrency` transformers over `_isProcessing` flags** — the right tool is a one-line transformer annotation. Manual flags are an easy source of deadlocks and missed edges.
- **mocktail only** — no generated mock files to regenerate on every build, no `@GenerateMocks` boilerplate. Works well with null safety.
- **GetIt scopes in tests over `allowReassignment`** — prevents cross-test leaks that `allowReassignment` quietly hides.
- **flutter_bloc over Riverpod (kept)** — a matter of project continuity. If starting fresh, Riverpod is a defensible alternative that collapses DI + state + caching. Not worth a migration when `bloc + get_it` is already well-organized.
