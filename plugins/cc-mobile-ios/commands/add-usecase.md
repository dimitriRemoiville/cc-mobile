---
description: Add a domain use case with a Swift Testing suite.
argument-hint: <UseCaseName> [--feature=<feature>]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

Add a new use case called **$ARGUMENTS**.

1. Read `.claude/skills/clean-architecture-ios/SKILL.md` to confirm where use cases live in this project.
2. Decide: does this use case need a new repository method, or does it compose existing ones? If new, add it to the repository protocol and its `Live…` implementation first.
3. Create the use case file in `<Feature>/Domain/UseCase/`. Prefer:

   ```swift
   struct <Name>UseCase {
       private let repository: <X>Repository
       private let now: () -> Date  // inject non-obvious dependencies

       init(repository: <X>Repository, now: @escaping () -> Date = Date.init) {
           self.repository = repository
           self.now = now
       }

       func callAsFunction(_ input: Input) async throws -> Output { /* ... */ }
   }
   ```

   `callAsFunction` lets callers write `useCase(input)`. The use case throws `DomainError` — never platform errors.

4. Create a Swift Testing suite in `Tests/.../<Name>UseCaseTests.swift`. At minimum cover: happy path + one error path.
5. Run: `xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AppTests/<Name>UseCaseTests`.
6. Report the new files and test results.
