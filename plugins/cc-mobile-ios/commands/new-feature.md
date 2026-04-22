---
description: Scaffold a full iOS feature (Data + Domain + Presentation) following the project's Clean Architecture conventions.
argument-hint: <feature-name> [--view=<ViewName>]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

You are scaffolding a new iOS feature called **$ARGUMENTS**.

Follow this sequence — do not skip steps:

1. **Load context.** Read `CLAUDE.md` and skim `.claude/skills/clean-architecture-ios/SKILL.md`, `.claude/skills/ios-di/SKILL.md`, and `.claude/skills/swiftui-views/SKILL.md`.
2. **Scan the existing codebase** for the nearest similar feature. Match its folder structure and naming. Do not introduce a new pattern unless there's a clear reason.
3. **Produce a short plan** (5–10 lines) listing every file you'll create or touch. Confirm with the user before writing if the plan introduces a new SPM package or changes `Package.swift` / project settings.
4. **Generate the feature** with this structure (adjust names):

   ```
   <Feature>/
   ├── Data/
   │   ├── Remote/<Feature>DTO.swift         # Codable DTOs
   │   ├── Mapper/<Feature>Mapper.swift      # DTO → Domain
   │   └── Repository/Live<Feature>Repository.swift
   ├── Domain/
   │   ├── Model/<Feature>.swift             # plain Swift
   │   ├── Repository/<Feature>Repository.swift  # protocol
   │   └── UseCase/Get<Feature>UseCase.swift
   └── Presentation/
       ├── <Feature>ViewState.swift
       ├── <Feature>ViewModel.swift          # @Observable @MainActor
       ├── <Feature>View.swift               # stateless + Root wrapper
       └── Navigation/<Feature>Route.swift   # if needed
   ```

5. **Wire DI** — extend `DIContainer` with a `makeXxxViewModel()` factory.
6. **Wire navigation** — add the route to `AppRoute` and the destination to the nav graph. Don't leave the screen unreachable.
7. **Tests.** Create at least:
   - Swift Testing suite for the use case.
   - Swift Testing suite for the mapper.
   - ViewModel test covering loading → loaded and an error path.
   - (Optional) XCUITest for the happy path if the project has a UI test target.

   Delegate to the `ios-tester` subagent via the Task tool for non-trivial suites.

8. **Verify** the build compiles and tests pass:
   - `xcodebuild build -scheme App -destination 'platform=iOS Simulator,name=iPhone 15'`
   - `xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AppTests/<NewSuite>`

9. **Report** what was created, link each file, and list any TODOs you left behind.

Hard rules:
- No `SwiftUI`, `UIKit`, `SwiftData`, or `URLSession` imports in `Domain/`.
- All view models are `@Observable @MainActor final class`. No `ObservableObject`.
- Dependencies injected through the initializer, not via singletons.
- Every new View has at least one `#Preview`.
