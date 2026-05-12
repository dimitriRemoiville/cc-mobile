---
description: Add a domain use case with a unit test.
argument-hint: <UseCaseName> [--feature=<feature>]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

Add a new use case called **$ARGUMENTS**.

1. Read `.claude/skills/android-architecture/SKILL.md` to confirm where use cases live in this project.
2. Decide: does this use case need a new repository method, or does it compose existing ones? Apply the **"When to add a use case"** rubric from that skill (the section that lists *Add when* / *Skip when* criteria — business logic, multi-repo composition, derived computation vs. trivial pass-through). If the call is genuinely ambiguous, delegate to `android-architect` via the `Task` tool — that's exactly what the architect agent is for. If a new repository method is needed, add it to the interface and implementation first.
3. Create the use case file in `<feature>/domain/usecase/` (feature-first; per `android-architecture` and `android-app-skeleton`). Prefer:

   ```kotlin
   class <Name>UseCase @Inject constructor(
       private val repository: <X>Repository,
   ) {
       suspend operator fun invoke(input: Input): Outcome<Output> { ... }
   }
   ```

   Use `suspend operator fun invoke` so callers can write `useCase(input)`. Return `Outcome<T>` (the project's canonical sealed result type — see `kotlin-style` and `android-app-skeleton`). Never throw across the boundary. `Result<T>` is reserved for data-layer scratch only, where it gets folded into `Outcome` via `core/data/network/Outcomes.kt` (`Result<T>.toOutcome(::toDomainError)`).

4. Create the unit test at `app/src/test/java/.../<feature>/domain/usecase/<Name>UseCaseTest.kt`. At minimum cover: happy path + one error path (assert against `Outcome.Failure(DomainError.X())`).
5. Run the test: `./gradlew :app:testDebugUnitTest --tests '*<Name>UseCaseTest'`.
6. Report the new files and test results.
