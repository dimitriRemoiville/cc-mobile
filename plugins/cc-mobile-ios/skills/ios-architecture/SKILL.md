---
name: ios-architecture
description: How MVVM + Clean Architecture is applied in this Swift + SwiftUI codebase — the `AppCore` / `AppFeatures` / `App` target split, the dependency rule, the `Outcome` boundary, and the "when to add a use case" rubric. Load when designing a new feature, deciding where code belongs, adding a repository or use case, or reviewing layer boundaries.
---

# iOS architecture (MVVM + Clean)

For Clean Architecture theory and MVVM basics, the [Apple app-architecture guidance](https://developer.apple.com/documentation/swiftui/model-data) and the usual Clean Architecture literature apply. This file documents the shape *this* project uses and the calls it has already made.

## When this applies

This skill describes **MVVM + Clean Architecture over three SPM targets with a composition root** — the shape `/init-ios-app` scaffolds. On an existing app that already chose differently, defer to it instead of refactoring:

- **TCA / The Composable Architecture** (`import ComposableArchitecture`, `@Reducer`, `Store<State, Action>`) — keep it. Don't push view models, use cases, or the `Outcome` contract; TCA has its own effect and dependency story.
- **MVI / Redux-style stores** (a single `dispatch(action)` entry point, a reducer) — keep it. Don't flag "user actions should be discrete view-model methods"; that rule is MVVM-only.
- **VIPER / MVP / MVC (UIKit)** — out of scope. This skill won't help and may mislead.
- **Single-target app, no SPM split** — very common and perfectly valid. The dependency *rule* still applies (domain depends on nothing); the *target boundary* that enforces it doesn't exist, so enforce it by review instead of by compiler.

Surface the mismatch in your summary (`This project is TCA, not MVVM — applying boundary guidance only`) and apply only the framework-agnostic principles: dependency direction, framework-free domain, errors mapped at the boundary.

## The dependency rule

```
App (composition root)  →  AppFeatures  →  AppCore
   URLSession, Keychain,      SwiftUI views,      Foundation only:
   SwiftData, Firebase        @Observable VMs     models, protocols, use cases
```

Arrows never reverse. `AppCore` imports **Foundation and nothing else** — no SwiftUI, no UIKit, no URLSession, no SwiftData, no Security. That constraint is what lets `AppCoreTests` run under `swift test` with no simulator.

`AppFeatures` depends on **protocols**, never implementations. `URLSessionAPIClient` and `KeychainStoreLive` live in `App` precisely so a feature can't reach for them by accident. If a feature needs one, it takes the protocol in its initializer and `App` supplies the live type.

The canonical layout, and the working `Splash` feature that demonstrates it, live in `${CLAUDE_PLUGIN_ROOT}/skills/ios-app-skeleton/SKILL.md` and its `references/`. Clone that shape when adding the next feature.

## Errors as values

**Domain-facing signatures return `Outcome<Success>`**, defined once in `AppCore` alongside the `DomainError` taxonomy. Repositories map `URLError` / `DecodingError` / `OSStatus` into `DomainError` at the boundary; nothing above the data layer knows those types exist. Full contract, including the `CancellationError` trap, in `swift-style`.

## When to add a use case

**Add one when:**

- There's business logic — validation, composition of multiple repositories, derived computation.
- Multiple view models call the same operation.
- The operation has testable branches that aren't interesting to exercise through a view model.

**Skip it when** the use case would literally be `repository.foo()` with no transformation. Inject the repository into the view model directly — but only if the rest of the codebase is consistent about that; a mix of both is worse than either.

Use cases are `struct`s with a single `callAsFunction`, so call sites read `try await submit(draft)`.

## Folders or SPM packages?

- **Start with the three scaffolded targets.** Add features as folders inside `AppFeatures`.
- **Promote a feature to its own package** when it's large, when build time is hurting, or when you want the compiler to enforce a boundary that review keeps failing to.
- **Don't over-modularize early.** Package boundaries are cheap to add and expensive to rearrange in Xcode.

## Feature checklist

Every item should exist before a feature is "done":

- [ ] Domain model in `AppCore` — `Sendable`, `Equatable`, no framework imports
- [ ] Repository protocol in `AppCore`, returning `Outcome<T>`
- [ ] Use case(s) in `AppCore` (if warranted by the rubric above)
- [ ] DTO + `toDomain()` mapper in the data layer
- [ ] `Live…Repository` in `App`, mapping platform errors to `DomainError`
- [ ] Registered in `CompositionRoot`
- [ ] `<Feature>ViewState` (+ `ViewAction` / `ViewEvent` if the screen needs them)
- [ ] `@Observable @MainActor final class` view model, constructor-injected
- [ ] `<Feature>RootView` + stateless `<Feature>View` + at least one `#Preview`
- [ ] Destination added to the typed route enum
- [ ] Tests for the use case, the mapper, and the view model
