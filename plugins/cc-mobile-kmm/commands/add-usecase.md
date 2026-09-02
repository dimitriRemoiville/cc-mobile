---
description: Add a use case in commonMain under an existing feature, plus a commonTest test.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# /add-usecase $ARGUMENTS

Add a single-purpose use case inside an existing feature in `shared/src/commonMain`. `$ARGUMENTS` is `<feature>/<UseCaseName>`, e.g. `order/SubmitOrderUseCase`.

## Before writing any code

Read `${CLAUDE_PLUGIN_ROOT}/skills/kmm-architecture/SKILL.md` and `${CLAUDE_PLUGIN_ROOT}/skills/kmm-testing/SKILL.md`. Confirm the use case really earns its keep (non-trivial logic, multi-repo orchestration, or the same operation used by several ViewModels). A one-liner wrapper around a repository call is not worth a use case — call the repository from the ViewModel instead.

## What to produce

1. `shared/src/commonMain/kotlin/com/example/app/feature/<feature>/domain/usecase/<Name>.kt`:
   ```kotlin
   class <Name>(
       private val repo: <Feature>Repository,
   ) {
       suspend operator fun invoke(/* params */): Result<SomeDomainType> = ...
   }
   ```
   - `suspend operator fun invoke` — call sites read `useCase(args)`.
   - Returns `Result<T>` with a `DomainError` on failure; never throws domain-relevant errors.
   - Always rethrow `CancellationException`.
2. Register the use case as a Koin `factory { ... }` in the feature's data module (or a domain module if one exists).
3. A test at `shared/src/commonTest/kotlin/.../usecase/<Name>Test.kt` that:
   - Uses `kotlin.test` + `kotlinx-coroutines-test` (`runTest`).
   - Constructs the use case with a hand-rolled fake of the repository.
   - Covers at minimum a success path and one failure path.

## After scaffolding

- Run `./gradlew :shared:allTests`.
- If the use case is part of a public API surface iOS consumes directly (rare — usually ViewModels are the surface), walk the `kmm-ios-interop` reviewer checklist.
