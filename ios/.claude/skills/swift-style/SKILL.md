---
name: swift-style
description: Project-specific Swift conventions — the rules that aren't already in Apple's API Design Guidelines. Covers the `Outcome<Success>` / `DomainError` boundary contract, typed IDs, use-case naming, the target-layer rules, and the logging privacy contract. Load whenever writing or reviewing Swift in this project.
---

# Swift style (project delta)

For everything not below, [Apple's API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) and the [Swift Book](https://docs.swift.org/swift-book/) apply — naming casing, optional handling, extensions, access control, pattern matching, collection idioms. This file only documents where this project's conventions add to or override those defaults.

## When this applies

The error-handling contract below is **opinionated for this project's scaffold** (`Outcome<Success>` + `DomainError` in `AppCore`, from `/init-ios-app`). On an existing app:

- Codebase uses `throws` + typed errors everywhere → don't refactor to `Outcome` unless the user asks. Apply only the boundary rule: platform errors (`URLError`, `DecodingError`, `NSError`) never cross into the domain.
- Codebase uses `Result<T, Error>` → same. `Outcome` is this scaffold's choice, not universal Swift practice; don't present it as one.
- Codebase is pre-Swift-6 (`swiftLanguageMode(.v5)`, no strict concurrency) → the `Sendable` and isolation rules in `swift-concurrency` are advisory, not errors.
- The naming and logging sections apply regardless of stack.

## Naming (project-specific)

- **Use cases**: verb-based type names suffixed `UseCase` — `GetUserProfileUseCase`, `SubmitOrderUseCase`. One `struct` per business action, exposing a single `callAsFunction` entry point so call sites read `try await submit(draft)`.
- **Repository protocols** live in `AppCore`; implementations live in `App` and are prefixed `Live` (`OrderRepository` ⇄ `LiveOrderRepository`). Test doubles are prefixed `Stub` / `Fake`.
- **Views**: `<Feature>RootView` for the stateful container, `<Feature>View` for the stateless presentation half. See `swiftui-views` for the split.
- **ViewState / ViewAction / ViewEvent**: one per screen, named `<Feature>ViewState` etc.
- **DTOs**: suffix `DTO` (`OrderDTO`), kept in the data layer next to their `toDomain()` mapper.

## Typed IDs

Wrap identifiers that would otherwise be a raw `String` / `Int`:

```swift
struct OrderID: Hashable, Sendable { let raw: String }
struct UserID: Hashable, Sendable { let raw: String }
```

Catches `get(id: userID)` mix-ups at compile time. Add `ExpressibleByStringLiteral` only if test ergonomics demand it — it reopens the hole for production call sites.

## Error-handling contract

**Domain-facing signatures return `Outcome<Success>`.** The two types are defined once in `AppCore` (`Outcome.swift`, `DomainError.swift` — see `.claude/skills/ios-app-skeleton/references/app-core.md`); every use case, repository method, and view model that needs a typed failure goes through them.

```swift
public enum Outcome<Success> {
    case success(Success)
    case failure(DomainError)
}

public enum DomainError: Error, Equatable, Sendable {
    case network(underlying: String? = nil)
    case unauthorized
    case notFound
    case server(code: Int)
    case unknown(String? = nil)
}
```

**Map platform errors at the repository boundary — never above it.** `URLError`, `DecodingError`, `APIError`, and `OSStatus` are data-layer vocabulary:

```swift
func get(id: OrderID) async -> Outcome<Order> {
    do {
        let dto: OrderDTO = try await client.get("/orders/\(id.raw)")
        return .success(dto.toDomain())
    } catch let error as URLError {
        return .failure(.network(underlying: error.localizedDescription))
    } catch is DecodingError {
        return .failure(.unknown("invalid response"))
    } catch {
        return .failure(.unknown(error.localizedDescription))
    }
}
```

`try!` and `as!` are review blockers. `try?` is acceptable only where the discarded error genuinely carries no information.

**`CancellationError` is not a domain failure.** A repository that maps it into `.failure(.unknown(...))` turns a cancelled screen into a visible error banner. Let it propagate, or `catch is CancellationError { return }` before the general `catch`. This is the single most common bug this contract prevents, and the reviewer flags it.

## Target boundaries

The scaffold is three SPM targets with one dependency direction: `AppCore` ← `AppFeatures` ← `App`.

- **`AppCore` imports Foundation and nothing else.** No SwiftUI, no UIKit, no URLSession, no SwiftData, no Security. An `import` of any of those in `AppCore` is a layer violation, not a style nit.
- **`AppFeatures` depends on protocols only.** `URLSessionAPIClient` and `KeychainStoreLive` live in `App` precisely so a feature cannot reach for them by accident.
- **`App` is the composition root** — the only place that constructs the object graph. See `ios-di`.

## Sealed hierarchies in this project

Three enums the codebase relies on — don't reinvent them:

- `Outcome<Success>` — every domain-facing result.
- `DomainError` — every domain-facing failure.
- `<Feature>ViewState` — every screen's state machine. Branches are `loading` / `error` / `loaded` by convention; add more only when the screen genuinely has them.

## Logging

- `Logger` from `os`, scoped per subsystem + category: `private let log = Logger(subsystem: "com.example.app", category: "Network")`.
- **No `print()` on a production code path.** The reviewer flags it.
- **Privacy modifiers are not optional.** Interpolated values default to `.private` for non-numeric types, but be explicit at every site that touches user data: `log.debug("user id=\(id, privacy: .private)")`. `%{public}@` / `privacy: .public` is for stable, non-identifying strings only — never a token, email, or URL carrying query parameters.
