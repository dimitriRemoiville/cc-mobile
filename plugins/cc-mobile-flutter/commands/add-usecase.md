---
description: Add a domain use case to a feature when it earns its keep (real logic, multi-repo orchestration, or reuse).
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# /add-usecase $ARGUMENTS

Add a use case under an existing feature. `$ARGUMENTS` is `<feature>/<VerbNoun>UseCase` (e.g. `auth/SignInUseCase`).

## Before writing any code

Read `${CLAUDE_PLUGIN_ROOT}/skills/flutter-architecture/SKILL.md`. Confirm the use case is worth its file — it should meet at least one:
- Orchestrates two or more repositories.
- Non-trivial transformation (validation, enrichment, time-based).
- Used by more than one bloc.
- Branching logic that's worth testing in isolation.

If it's a one-line pass-through to a repository, **don't add a use case**. Call the repository from the bloc.

## File

```dart
// lib/feature/<feature>/domain/usecases/<verb>_<noun>_use_case.dart

final class SignInUseCase {
  const SignInUseCase({
    required AuthRepository authRepository,
    required UserProfileRepository profileRepository,
    required ILogger logger,
  })  : _auth = authRepository,
        _profile = profileRepository,
        _logger = logger;

  final AuthRepository _auth;
  final UserProfileRepository _profile;
  final ILogger _logger;

  Future<Either<Failure, SignInOutcome>> call({
    required String email,
    required String password,
  }) async {
    final signed = await _auth.signIn(email: email, password: password);
    return signed.fold(
      Left.new,
      (user) async {
        final profile = await _profile.fetch(userId: user.id);
        return profile.fold(
          Left.new,
          (p) => Right(SignInOutcome(user: user, profile: p)),
        );
      },
    );
  }
}
```

Rules:
- Use `call` as the single public method — call sites read `await signIn(email: ..., password: ...)`.
- Return `Future<Either<Failure, T>>`.
- Never throw domain-relevant errors. Rethrow `CancelledFailure`-style cancellations only if the repo didn't already.
- Construct with constructor injection; register as `registerFactory` in the feature module.

## Register

```dart
sl.registerFactory<SignInUseCase>(() => SignInUseCase(
      authRepository: sl(),
      profileRepository: sl(),
      logger: sl(),
    ));
```

## Test

```
test/feature/<feature>/domain/usecases/<name>_use_case_test.dart
```

- Construct with hand-rolled fakes for each repository.
- Cover success, each failure source, and at least one coordination case (repo A succeeds, B fails).

## Checklist

- [ ] The use case carries real logic — not a pass-through.
- [ ] Registered as `registerFactory` in the feature module.
- [ ] Tested in isolation with fakes.
- [ ] No Flutter imports in this file.
