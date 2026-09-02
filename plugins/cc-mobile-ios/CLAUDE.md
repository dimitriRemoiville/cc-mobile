# CLAUDE.md — iOS stack

This file gives Claude Code the project context it needs to work effectively on the **iOS** target. Claude Code reads this automatically at the start of every session in this folder.

## Project

A native iOS application written in **Swift** with **SwiftUI** as the UI framework. The codebase follows **MVVM + Clean Architecture** and uses **Swift Concurrency** (`async/await`, `Task`, `AsyncSequence`, actors) throughout. Dependencies are managed with **Swift Package Manager**; dependency injection uses a manual **composition root + initializer injection** pattern.

This is the iOS counterpart to the Android stack one folder over. Conventions are aligned where it makes sense, and intentionally platform-idiomatic where it doesn't.

## Tech stack

- **Language:** Swift 6 (strict concurrency enabled); deployment target iOS 18+ unless a specific project requires older. iOS 18 gets us `@Entry` for Environment values, the improved `NavigationStack` ergonomics (typed path bindings without boilerplate), and the polished `.scrollPosition(id:)` behaviour.
- **UI:** SwiftUI (+ UIKit interop via `UIViewRepresentable` / `UIHostingController` when needed)
- **State:** `@Observable` (Swift Observation framework), `@State`, `@Binding`, `@Environment`
- **Architecture:** MVVM + Clean Architecture (Presentation / Domain / Data layers)
- **DI:** Composition root + constructor injection; protocols for testability
- **Concurrency:** Swift Concurrency (`async/await`, `Task`, `AsyncSequence`, actors, `@MainActor`)
- **Networking:** `URLSession` + `async/await` + `Codable` (add Alamofire only if genuinely needed)
- **Persistence:** SwiftData for models that belong to the user; `UserDefaults` / `@AppStorage` for preferences; Keychain for secrets
- **Navigation:** `NavigationStack` with typed destinations (value-based navigation)
- **Images:** `AsyncImage` for simple cases; add Nuke/Kingfisher only for advanced needs
- **Testing:** Swift Testing (`@Test`, `#expect`, `#require`) for unit/integration; XCTest for UI tests

## Package / folder layout

**SPM-first: three targets, one dependency direction** — `AppCore` ← `AppFeatures` ← `App`. This is what `/init-ios-app` scaffolds and what `ios-architecture` describes.

```
Sources/
├── AppCore/          # framework-free domain — Foundation only
│   ├── Outcome.swift, DomainError.swift
│   ├── <Feature>/Model/, Repository/ (protocols), UseCase/
│   └── APIClient.swift, KeychainStore.swift   # protocols
├── AppFeatures/      # SwiftUI views + @Observable view models
│   ├── <Feature>/{<Feature>RootView, <Feature>View, <Feature>ViewModel, <Feature>ViewState}.swift
│   └── Navigation/Destination.swift
└── App/              # the only target that knows concrete frameworks
    ├── CompositionRoot.swift
    ├── URLSessionAPIClient.swift, KeychainStoreLive.swift
    └── Live<Feature>Repository.swift          # DTOs + mappers live here
```

Dependency direction is always **App → AppFeatures → AppCore**. `AppCore` imports `Foundation` and nothing else — no `SwiftUI`, `UIKit`, `URLSession`, `SwiftData`, or `Security`. That constraint is what lets `AppCoreTests` run under `swift test` with no simulator, and it's enforced by the target boundary rather than by convention.

On an existing single-target app the targets don't exist, but the rule does — enforce it by review instead of by compiler.

## Conventions

**Naming**
- Types: `UpperCamelCase` (`UserProfileView`, `GetUserProfileUseCase`).
- Functions, properties: `lowerCamelCase`.
- Use cases: verb-based (`GetUserProfileUseCase`, `SubmitOrderUseCase`), exposing a `callAsFunction` or a single method (`execute` / `invoke`).
- Protocols: plain nouns (`UserRepository`), not `…able` or `I…` — e.g. `UserRepository`, not `IUserRepository`.
- Implementations suffixed `Impl` or with concrete purpose (`LiveUserRepository`, `MockUserRepository`).

**State**
- View models are `@Observable final class` types (Swift 5.9+ `Observation` framework), marked `@MainActor` when they update UI state.
- ViewState is a value type — preferably an `enum` when states are distinct (`loading`, `loaded(Data)`, `error(Error)`), otherwise a `struct`.
- One-off effects (navigation, alerts, toasts) travel through an `AsyncStream<ViewEvent>` or a dedicated callback, not through ViewState.

**Views**
- Separate **stateless** views (take state + callbacks) from **stateful** container views that own the ViewModel. The container is usually named `…RootView` or `…Route`.
- Views get at least one `#Preview` with representative data; multi-state previews use `PreviewProvider`-style helpers or multiple `#Preview` macros.
- Use `Environment` for things that are truly environmental (theme, locale, currentUser) — not as a general DI mechanism.

**Concurrency**
- `@MainActor` on anything that touches UI state; keep heavy work in async functions and `Task.detached` only with good reason.
- Never use `DispatchQueue.main.async { }` in new code — use `await MainActor.run { … }` or mark the function/type `@MainActor`.
- Cancellation is cooperative — use `Task.checkCancellation()` in long loops; honour `CancellationError`.
- Prefer structured concurrency (`async let`, `TaskGroup`) over detached tasks.

**Errors**
- Domain-facing signatures return `Outcome<T>` (the sealed result type in `AppCore`, alongside the `DomainError` taxonomy). On a codebase that predates it, `throws` a `DomainError` is the equivalent — either way a platform error (`URLError`, `DecodingError`, `NSError`, `OSStatus`) never crosses a layer boundary.
- Network/IO errors are mapped at the repository boundary.
- `CancellationError` is not a domain failure — let it propagate, or `catch is CancellationError { return }` before the general `catch`. Folding it into an error state paints a banner over a screen the user already left.

## Build

- Swift Package Manager for dependencies (`Package.swift` or Xcode SPM integration). Pin versions; don't use `.branch(...)`.
- `xcodebuild` from CI: `xcodebuild -scheme App -destination 'platform=iOS Simulator,name=iPhone 15' build`.
- Tests: `xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=iPhone 15'`.
- Linting: SwiftLint and/or SwiftFormat if configured.

## What Claude should do

- **Prefer editing existing files** to creating new ones. Only create files when a new feature genuinely needs them.
- **Respect layer boundaries.** No `SwiftUI` / `UIKit` / `SwiftData` / `URLSession` / `Security` imports in `AppCore`, and no concrete implementation types in `AppFeatures` — it depends on protocols only.
- **Write tests** for new use cases and view models. Prefer **Swift Testing** (`@Test`) for new test targets; extend existing XCTest targets rather than duplicating.
- **Use `@Observable` for view models.** Do not use `ObservableObject` / `@Published` in new code unless the app targets < iOS 17.
- **Honour Swift 6 strict concurrency.** If a type needs `Sendable`, add it explicitly. Don't suppress warnings with `@unchecked Sendable` without justification.
- **Keep views small.** Extract a subview when a `body` exceeds ~40 lines or nests more than two levels.

## Specialist agents

Use the `Task` tool with these subagents for focused work (see `${CLAUDE_PLUGIN_ROOT}/agents/`):

- `ios-architect` — architectural decisions, module boundaries, trade-offs.
- `ios-ui-engineer` — building SwiftUI screens and components.
- `ios-reviewer` — code review focused on Swift/iOS idioms and concurrency.
- `ios-tester` — writing unit, async, and UI tests.
- `ios-build-expert` — Swift Package Manager, build settings, Xcode project quirks.
- `ios-security-reviewer` — auth, Keychain, ATS, URLSession, WebView, Info.plist permission strings.
- `ios-a11y-reviewer` — VoiceOver labels/traits, Dynamic Type, contrast, hit-target sizing.
- `ios-performance-analyst` — cold start, scroll jank, memory growth, Instruments / signpost analysis.
- `ios-release-engineer` — version bumps, signing, App Store Connect metadata, fastlane / `xcodebuild archive`.

## Useful slash commands

See `${CLAUDE_PLUGIN_ROOT}/commands/`:

- `/init-ios-app` — scaffold a brand-new iOS app from scratch (Swift 6, SwiftUI, SPM, composition-root DI, Keychain, NavigationStack with typed destinations, Swift Testing). Verifies the toolchain floor and resolves any third-party SPM tags online.
- `/new-feature` — scaffold a full feature (Data + Domain + Presentation).
- `/add-view` — add a SwiftUI view + ViewModel + ViewState.
- `/add-usecase` — add a use case with a test.
- `/add-migration` — add a SwiftData schema migration.
- `/upgrade-deps` — refresh SPM tags against the GitHub Releases API.
- `/fix-tests` — investigate + fix failing tests on the current branch.
- `/review-ios` — run a review pass with `ios-reviewer`.
