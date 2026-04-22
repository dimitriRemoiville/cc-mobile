# Flutter project — working conventions

Read this first. It sets the defaults for every file in `lib/`.

## Stack

- **Language:** Dart 3 (sealed classes, pattern matching, records).
- **UI:** Flutter 3.35+ with Material 3.
- **State management:** `flutter_bloc` (Bloc for event-driven flows, Cubit for simple state holders). `formz` for form field state.
- **Routing:** `go_router` with **typed routes** (via `go_router_builder`), not string enums.
- **DI:** `get_it` as a service locator, with **feature-level registration modules** and **GetIt scopes** per test.
- **Networking:** `dio` + an OpenAPI-generated API client package. Repositories call the generated client — not `dio` directly.
- **Error model:** `fpdart`'s `Either<Failure, T>` at the repository boundary. `Failure` is a Dart 3 `sealed class`.
- **Immutability + codegen:** `freezed` for states, entities, and union types. `json_serializable` for wire-level DTOs.
- **Persistence:** `drift` (+ `sqlcipher_flutter_libs` for encrypted local DB), `shared_preferences`, `flutter_secure_storage`.
- **Observability:** Firebase Crashlytics + Analytics + Remote Config behind a thin service interface.
- **Testing:** `flutter_test` + `bloc_test` + `mocktail`. `alchemist` (or `golden_toolkit`) for golden tests on design-system components.
- **Concurrency safety:** `bloc_concurrency` transformers (`droppable`, `restartable`, `sequential`) — no manual `_isProcessing` flags.

## Project layout

Single-app layout (if the app is part of a monorepo, put this under `apps/<app-name>/`):

```
lib/
├── main_dev.dart                    # dev flavor entry point
├── main_prod.dart                   # prod flavor entry point
├── app_initializer.dart             # shared bootstrapping (DI, Firebase, services)
├── <app>_app.dart                   # root widget, injects router + theme
├── routing/                         # go_router + typed routes
├── core/                            # cross-cutting infra
│   ├── analytics/
│   ├── auth/                        # token store, auth state stream
│   ├── config/                      # AppConfig (flavor, env, base URLs)
│   ├── crashlytics/
│   ├── database/                    # drift setup, DAOs live here or per-feature
│   ├── di/                          # GetIt container + root registration
│   ├── errors/                      # Failure sealed class + extensions
│   ├── localization/
│   ├── logging/                     # ILogger interface + impl
│   ├── network/                     # DioFactory, ApiCallErrorHandling mixin
│   ├── notifications/
│   └── remote_config/
├── feature/                         # one folder per feature
│   └── <feature>/
│       ├── di/<feature>_module.dart # feature-local GetIt registrations
│       ├── data/
│       │   ├── repositories/
│       │   ├── datasources/         # local + remote sources if split
│       │   └── mappers/             # DTO ↔ entity mappers
│       ├── domain/
│       │   ├── entities/
│       │   ├── repositories/        # interfaces only
│       │   └── usecases/            # only when they carry real logic
│       └── presentation/
│           ├── bloc/<name>_bloc.dart (+ events, states files)
│           ├── pages/
│           └── widgets/
├── shared/                          # widgets + models reused across features
│   ├── widgets/
│   ├── theme/
│   └── utils/
└── l10n/                            # generated via flutter_localizations
```

## Conventions

### Layer discipline

```
presentation → domain ← data
```

- `presentation/` imports from `domain/` only.
- `data/` imports from `domain/` only.
- `domain/` imports from **nothing** in your app — no Flutter, no packages other than `fpdart`, `uuid`, and other pure Dart deps.
- No DTO/generated-API-client type ever crosses into `presentation/`. Map in the repository.

### Repository contract

- Interface in `domain/repositories/`, implementation in `data/repositories/`.
- Methods return `Future<Either<Failure, T>>` — never throw for domain-relevant errors.
- Use the `ApiCallErrorHandling` mixin to map `DioException` → `Failure` consistently.
- Drift access goes through DAOs, not raw queries, in the repository layer.

### State and events

- States are `@freezed` unions for blocs with distinct phases (`Loading`, `Success`, `Error`).
- Cubits with a single state class use a freezed `@Default`-decorated data class.
- Events are a `sealed class` (freezed union works too). The bloc's `on<E>` handlers `.match` exhaustively.
- One-shot effects (toasts, navigation) leave the bloc through a `Stream<UiEvent>` (e.g., a `StreamController.broadcast`) or a `BlocListener` at the call site with `listenWhen` — **not** as a state transition.

### Event concurrency

Don't guard with booleans. Use `bloc_concurrency`:

```dart
on<SignIn>(_onSignIn, transformer: droppable());   // ignore while in-flight
on<Search>(_onSearch, transformer: restartable()); // cancel in-flight
on<Enqueue>(_onEnqueue, transformer: sequential()); // serialize
```

### Routing

Use `go_router_builder` typed routes. No string enums:

```dart
@TypedGoRoute<ActivityRoute>(path: '/activity/:id')
class ActivityRoute extends GoRouteData {
  const ActivityRoute({required this.id});
  final String id;
  @override
  Widget build(BuildContext context, GoRouterState state) => ActivityPage(id: id);
}

// call site:
const ActivityRoute(id: activityId).go(context);
```

### DI

- `GetIt` is registered in `initializeDependencies()`, which is called from `AppInitializer.initialize()` at startup.
- Each feature exposes `void register<Feature>Module(GetIt sl)` in its `di/` folder; `initializeDependencies()` calls each.
- `registerLazySingleton` for infra (logger, db, repositories). `registerFactory` for blocs and use cases.
- **Never** resolve from `GetIt` inside a widget's `build`. Inject via constructor or a `BlocProvider`.
- Tests **don't** use `allowReassignment = true`. They use `GetIt.I.pushNewScope()` / `popScope()` or bypass GetIt entirely by constructing the class under test with fakes.

### Error model

```dart
sealed class Failure {
  const Failure({required this.message, this.code, this.rootCause, this.stackTrace});
  final String message;
  final String? code;
  final Object? rootCause;
  final StackTrace? stackTrace;
}

final class NetworkFailure extends Failure { ... }
final class ServerFailure extends Failure { ... }   // 5xx
final class AuthFailure extends Failure { ... }     // 401 / 403
final class NotFoundFailure extends Failure { ... } // 404
final class ValidationFailure extends Failure { ... }
final class CacheFailure extends Failure { ... }
final class CancelledFailure extends Failure { ... }
final class RateLimitFailure extends Failure { ... }
final class UnknownFailure extends Failure { ... }
```

All repository error paths go through `Failure`. The UI pattern-matches on it.

### Async cleanup

These are treated as errors by analysis (`cancel_subscriptions`, `close_sinks`, `unawaited_futures`, `use_build_context_synchronously`). Don't silence them; fix them.

### Naming

- Files: `snake_case.dart`, mirroring the class name (`auth_bloc.dart` → `AuthBloc`).
- States: `<Feature>State`, events: `<Feature>Event`, Bloc: `<Feature>Bloc`.
- Use `final` for all locals unless reassignment is unavoidable.

## Analysis

`analysis_options.yaml` extends `package:flutter_lints/flutter.yaml` plus:

```yaml
linter:
  rules:
    always_use_package_imports: true
    avoid_print: true
    cancel_subscriptions: true
    close_sinks: true
    prefer_const_constructors: true
    prefer_final_locals: true
    omit_local_variable_types: true
    unawaited_futures: true
    use_build_context_synchronously: true
```

Treat analyzer warnings as build failures locally — run `dart analyze --fatal-infos --fatal-warnings` in CI.

## Testing

- **Blocs:** `blocTest<AuthBloc, AuthState>(...)` with `seed`, `act`, and `expect`.
- **Repositories:** mock the generated API client with `mocktail`; assert on `Either.fold`.
- **Widgets:** `pumpWidget` a stateless widget with a fake bloc-like surface (a plain object that exposes `add` and a state stream) rather than mocking `Bloc` directly.
- **Goldens:** run on CI under a single matrix (Linux runner) to avoid font drift. Each design-system widget gets a golden.
- **Don't** share state between tests. One concept per test.

## Build & run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generate freezed, drift, go_router_builder, json_serializable
flutter run --flavor dev --target lib/main_dev.dart
flutter run --flavor prod --target lib/main_prod.dart

flutter test                                               # unit + widget
flutter test --update-goldens                              # regenerate goldens
dart analyze --fatal-infos --fatal-warnings
dart format --set-exit-if-changed .
```

## Hard nos

- No business or navigation state in `setState`. Ephemeral UI toggles (expanded/collapsed, focus state, form field show/hide) are fine in `setState` or a small `ValueNotifier`; anything that survives a rebuild or drives a side effect goes through a Bloc/Cubit.
- No `Navigator.push` with an ad-hoc `MaterialPageRoute`. Use the typed `go_router`.
- No `GetIt` lookups inside `build`.
- No DTOs, JSON, or generated-API types in `presentation/`.
- No `dartz`. Use `fpdart`.
- No `Equatable` on new state/entity classes. Use `freezed`.
- No `mockito`. Use `mocktail`.
- No string-based route paths scattered in call sites. One source of truth in `routing/`.
- No `print`. Use `ILogger`.
