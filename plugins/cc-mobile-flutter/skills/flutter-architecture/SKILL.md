---
name: flutter-architecture
description: How MVVM + Clean Architecture is applied in this Flutter codebase — feature layout, layer rules, repository contract, when to add a use case, error model. Load when designing a new feature, deciding where code belongs, adding a repository or use case, or reviewing layer boundaries.
---

# Clean Architecture (Flutter)

Every feature is a little vertical slice. Three layers. Nothing below knows anything above.

```
presentation/  ← Bloc, pages, widgets
      ↓
   domain/     ← entities, repository interfaces, use cases
      ↑
   data/       ← repository implementations, DTOs, mappers, local sources
```

## Feature folder

```
feature/<feature>/
├── di/<feature>_module.dart       # GetIt registration for this feature
├── data/
│   ├── datasources/               # local (drift DAO) + remote (api client wrapper) if split
│   ├── mappers/                   # DTO ↔ entity
│   └── repositories/<name>_repository_impl.dart
├── domain/
│   ├── entities/<name>.dart       # freezed
│   ├── repositories/<name>_repository.dart   # interface only
│   └── usecases/<verb>_<noun>_use_case.dart  # only when logic earns it
└── presentation/
    ├── bloc/<name>_bloc.dart (+ events.dart, states.dart)
    ├── pages/<name>_page.dart      # BlocProvider + listeners
    └── widgets/                    # screen-local widgets, plus a stateless <Name>View
```

## Layer rules

- `presentation/` imports only from `domain/` + Flutter + `shared/`.
- `data/` imports only from `domain/` + networking/persistence libs.
- `domain/` imports only pure Dart (`fpdart`, `uuid`, `intl` if truly shared). **No Flutter, no Firebase, no dio, no drift.**
- A DTO type from the generated API client **never** appears above `data/`. Map in the repository.

## Use case — or not

A use case earns its file when at least one is true:
- Orchestrates two or more repositories.
- Non-trivial transformation (validation, enrichment, time-based logic).
- Reused by more than one bloc.
- Has branching logic worth testing in isolation.

If the "use case" is a one-line pass-through (`repo.getX()` → `useCase()` → `repo.getX()`), delete the file and call the repository directly from the bloc. This is the single biggest source of dead code in clean-architecture apps.

## Repository contract

```dart
// domain/repositories/activity_repository.dart
abstract interface class ActivityRepository {
  Future<Either<Failure, Activity>> getActivity(String id);
  Future<Either<Failure, List<Activity>>> listActivities({String? cursor});
  Stream<Either<Failure, Activity>> watchActivity(String id);
}
```

Implementation rules (see `${CLAUDE_PLUGIN_ROOT}/skills/dio-networking/SKILL.md` for the detailed mapping):

```dart
// data/repositories/activity_repository_impl.dart
final class ActivityRepositoryImpl
    with ApiCallErrorHandling
    implements ActivityRepository {

  ActivityRepositoryImpl({
    required ActivitiesApi api,        // from generated client
    required ActivityDao dao,          // drift
    required ILogger logger,
  }) : _api = api, _dao = dao, _logger = logger;

  final ActivitiesApi _api;
  final ActivityDao _dao;
  final ILogger _logger;

  @override
  Future<Either<Failure, Activity>> getActivity(String id) =>
      handleApiCall(
        () => _api.getActivity(id: id),
        map: (dto) => dto.toDomain(),
      );
}
```

- `handleApiCall` (from `ApiCallErrorHandling`) runs the call, maps DTOs, catches `DioException`, and returns `Either<Failure, T>`.
- **Always rethrow `CancelledFailure`-equivalent cancellation** — `DioException.type == DioExceptionType.cancel` maps to `CancelledFailure`, which the UI typically ignores.

## Mappers

One direction only: DTO → entity. Keep them as free functions or extension methods on the DTO, one file per feature:

```dart
// data/mappers/activity_mapper.dart
extension ActivityDtoMapper on ActivityDto {
  Activity toDomain() => Activity(
        id: id,
        title: title,
        kind: switch (kind) {
          'video' => ActivityKind.video,
          'audio' => ActivityKind.audio,
          _ => ActivityKind.unknown,
        },
      );
}
```

Never map entity → DTO unless you're hand-rolling a write. The generated client takes care of outbound shapes.

## Failure model

```dart
// core/errors/failures.dart
sealed class Failure {
  const Failure({required this.message, this.code, this.rootCause, this.stackTrace});
  final String message;
  final String? code;
  final Object? rootCause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType($message${code == null ? '' : ', code: $code'})';
}

final class NetworkFailure    extends Failure { const NetworkFailure({super.message = 'Network error', super.rootCause, super.stackTrace}); }
final class ServerFailure     extends Failure { const ServerFailure({required super.message, super.code, super.rootCause, super.stackTrace}); }
final class AuthFailure       extends Failure { const AuthFailure({super.message = 'Unauthorized', super.code, super.rootCause, super.stackTrace}); }
final class NotFoundFailure   extends Failure { const NotFoundFailure({required super.message, super.code}); }
final class ValidationFailure extends Failure { const ValidationFailure({required super.message, this.fields = const {}}) : super(code: 'validation'); final Map<String, String> fields; }
final class CacheFailure      extends Failure { const CacheFailure({required super.message, super.rootCause, super.stackTrace}); }
final class CancelledFailure  extends Failure { const CancelledFailure() : super(message: 'Cancelled'); }
final class RateLimitFailure  extends Failure { const RateLimitFailure({required this.retryAfter}) : super(message: 'Rate limited'); final Duration retryAfter; }
final class UnknownFailure    extends Failure { const UnknownFailure({required super.message, super.rootCause, super.stackTrace}); }
```

UI handles them via pattern match:

```dart
switch (failure) {
  AuthFailure() => ShowSignInPrompt(),
  NetworkFailure() => OfflineBanner(),
  ValidationFailure(:final fields) => InlineErrors(fields),
  _ => GenericError(failure.message),
};
```

## When to split a feature

Split into two features when:
- Two routes in the same feature don't share entities or repositories.
- One half of the feature is only used by a different feature, not by its "own" routes.
- Different teams own them.

Otherwise keep it together. Many small features are more ceremony than one well-organized feature.

## `core/` vs `shared/`

- **`core/`** — infrastructure and cross-cutting services: DI, logging, analytics, network factory, database setup, Firebase wrappers, failure model.
- **`shared/`** — UI and domain atoms reused by features: design-system widgets, theme, formatting utilities, common models used by multiple features.

If you catch yourself writing `shared/<feature-name>/`, stop. It's a feature.

## Checklist for a new feature

- [ ] `domain/entities/` — freezed entity (or several).
- [ ] `domain/repositories/<name>_repository.dart` — interface, `Future<Either<Failure, T>>` returns.
- [ ] `data/mappers/` — DTO → entity.
- [ ] `data/repositories/<name>_repository_impl.dart` — uses generated API client + DAO.
- [ ] `presentation/bloc/` — states + events (freezed) + bloc using `bloc_concurrency` transformers.
- [ ] `presentation/pages/<name>_page.dart` — `BlocProvider` + `BlocListener` for side effects.
- [ ] `presentation/widgets/<name>_view.dart` — stateless, tested with `pumpWidget`.
- [ ] `di/<feature>_module.dart` — registrations; called from `initializeDependencies()`.
- [ ] `routing/` — typed `GoRouteData` for any new routes.
- [ ] Tests in `test/feature/<feature>/`.
