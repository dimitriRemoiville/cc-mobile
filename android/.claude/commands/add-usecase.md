---
description: Add a domain use case with a unit test.
argument-hint: <UseCaseName> [--feature=<feature>]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

Add a new use case called **$ARGUMENTS**.

1. Read `.claude/skills/clean-architecture/SKILL.md` to confirm where use cases live in this project.
2. Decide: does this use case need a new repository method, or does it compose existing ones? If new, add it to the repository interface and implementation first.
3. Create the use case file in `<feature>/domain/usecase/`. Prefer:

   ```kotlin
   class <Name>UseCase @Inject constructor(
       private val repository: <X>Repository,
   ) {
       suspend operator fun invoke(input: Input): Result<Output> { ... }
   }
   ```

   Use `suspend operator fun invoke` so callers can write `useCase(input)`. Return `Result<T>` or a sealed outcome — never throw across the boundary.

4. Create the unit test in `src/test/.../<Name>UseCaseTest.kt`. At minimum cover: happy path + one error path.
5. Run the test: `./gradlew :app:testDebugUnitTest --tests '*<Name>UseCaseTest'`.
6. Report the new files and test results.
