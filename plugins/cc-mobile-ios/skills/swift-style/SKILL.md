---
name: swift-style
description: Swift coding conventions and idioms enforced on this project. Load whenever writing or reviewing Swift — naming, value vs. reference types, optionals, error handling, concurrency, Sendable, access control, and when to use extensions / protocols / generics.
---

# Swift style

## Naming

- `UpperCamelCase` for types (classes, structs, enums, protocols, typealiases).
- `lowerCamelCase` for functions, methods, properties, enum cases.
- Boolean getters: `isEmpty`, `hasNext`, `canSubmit`.
- Protocols: plain nouns (`UserRepository`) or `…ing` / `…able` when they describe a capability (`Encoding`, `Cancellable`).
- Use cases: verb-based type names (`GetUserProfileUseCase`), exposing a single entry point (`callAsFunction` or `execute`).

## Value vs. reference types

- **Default to `struct`.** Reach for `class` only when you need reference semantics (identity, shared mutable state) or Objective-C interop.
- **`enum` for closed hierarchies** — ViewState, DomainError, Route. Prefer enums with associated values over type hierarchies of classes.
- **`actor`** for types that own mutable state accessed from multiple tasks — e.g. a cache, an in-memory database.

## Optionals

- Prefer non-optional types. A nullable return should carry meaning.
- `!` force-unwraps are a smell. Replace with:
  - `guard let x = foo else { return … }` when the rest of the function can't continue.
  - `if let x = foo { … }` when the branch matters.
  - `foo ?? fallback` when there's a sensible default.
  - `foo.map { … }` / `foo.flatMap { … }` when chaining transforms.
  - `x!` when you've already `guard`ed or `if let`ed the same thing — just use the unwrapped binding.
- `try!` is almost always wrong. `try?` is fine when you truly don't care about the error.

## Error handling

- Throw domain errors. Domain-facing functions `throws` a `DomainError` (or return `Result<T, DomainError>`).
- Map platform errors at the boundary:

  ```swift
  func getOrder(id: OrderID) async throws -> Order {
      do {
          return try await api.getOrder(id).toDomain()
      } catch let error as URLError {
          throw DomainError.network(error.code)
      } catch is DecodingError {
          throw DomainError.invalidResponse
      } catch {
          throw DomainError.unknown(error.localizedDescription)
      }
  }
  ```

- `Result<T, DomainError>` is equivalent to `throws` — pick one style per layer and stick with it.

## Concurrency

- `async` / `await` for one-shot async work.
- `AsyncSequence` / `AsyncStream` for streams.
- `Task { }` creates an unstructured task; prefer `async let`, `TaskGroup`, or `.task { }` when possible.
- `Task.detached` drops actor context — only use when that's intended.
- `@MainActor` on anything that updates UI state.
- `Sendable` on types crossing actor boundaries. Add it explicitly when the compiler can't infer it.
- Use `@unchecked Sendable` sparingly and document the invariant.
- Cancellation is cooperative: check `Task.checkCancellation()` in long loops; honour `CancellationError`.

## Extensions

- Use extensions to:
  - Add methods to types you don't own (`String`, `URL`).
  - Break up a large type for readability (main type + extension per protocol conformance).
- Don't use extensions to hide state. Stored properties live with the main declaration.

## Access control

- `internal` is the default (and usually correct for module-internal APIs).
- `private` for file-/type-internal helpers.
- `fileprivate` when a helper is used across types in the same file.
- `public` / `open` should be deliberate — they pin API shape.

## Collections and iteration

- `[Element]`, `[Key: Value]`, `Set<Element>`. Use these literals.
- `map`, `filter`, `reduce`, `compactMap`, `flatMap` — prefer over imperative `for` loops when it makes intent clearer.
- Lazy sequences (`array.lazy.map…`) when you need to avoid materializing intermediates.

## Pattern matching

- `switch` over values whenever the type is an enum — the compiler enforces exhaustiveness.
- Destructure associated values: `case .loaded(let profile): …`.
- `if case let .loaded(p) = state { … }` for a single-branch match.
- Use `where` clauses for compound conditions.

## Functions

- Default parameters > overload explosions.
- Argument labels help readability: `func move(from source: Point, to destination: Point)`.
- Prefer small functions; if a function is 50+ lines, it's doing too much.

## Logging

- Use `Logger` from `os`: `private let log = Logger(subsystem: "com.example.app", category: "Network")`.
- No `print()` in production code paths.
- Redact PII in logs: `logger.log("user id=\(id, privacy: .private)")`.

## Common pitfalls

- **Retain cycles in closures:** use `[weak self]` in long-lived closures stored on `self`.
- **Force-casts:** `as!` is as bad as `!`. Use `as?` + fallback.
- **`AnyObject`:** rarely the right abstraction. Use protocols.
- **Global state:** Swift makes it easy; resist. Inject dependencies.
