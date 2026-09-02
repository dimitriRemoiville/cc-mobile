---
name: swift-concurrency
description: Project-specific Swift 6 concurrency rules — the isolation map this codebase uses (`@MainActor` view models, `actor` repositories, `Sendable` domain types), the cancellation contract, the approachable-concurrency opt-in, and the hard nos the reviewer enforces. Load whenever touching async code, cross-actor boundaries, or long-running work.
---

# Swift concurrency (project delta)

For concurrency fundamentals — how `actor` isolation works, what `Sendable` means, `async let` vs `TaskGroup`, `AsyncStream` construction, how cancellation propagates — read [Apple's Swift Concurrency documentation](https://developer.apple.com/documentation/swift/concurrency) and the [Swift 6 migration guide](https://www.swift.org/migration/documentation/migrationguide/). This file documents only this project's decisions.

## When this applies

**Swift 6 language mode with strict concurrency on** — the floor `/init-ios-app` scaffolds. On an existing app:

- **Swift 5 language mode** (`swiftLanguageMode(.v5)`, or `SWIFT_STRICT_CONCURRENCY` unset / `minimal`) → the isolation rules below are advisory. Report `Sendable` gaps as risks, not as build errors, and don't propose a mode flip as a side effect of an unrelated change — it's its own migration.
- **Combine-based codebase** (`AnyCancellable`, `PassthroughSubject`, `.sink` stored in `cancellables`) → don't rewrite to async/await unasked. Apply the isolation and cancellation principles to whatever new async code is being added, and leave the Combine graph alone.
- **UIKit + `DispatchQueue`** → the "no `DispatchQueue.main.async`" rule is for new SwiftUI code. Legacy UIKit call sites stay as they are until someone migrates them deliberately.

## The isolation map

Every type in this codebase falls into one of four buckets. Deviating from the map needs a reason in the PR description:

| Kind | Isolation | Why |
|---|---|---|
| `View`, view models, coordinators | `@MainActor` | They read or write UI state. |
| Repositories that own mutable state (caches, contexts) | `actor` | Serialized access without a lock. |
| Repositories that are stateless pass-throughs | `struct` + `Sendable` | Nothing to protect; don't pay for an actor hop. |
| Domain models (`AppCore`) | `Sendable` value types | They cross every boundary. |

```swift
@Observable @MainActor
final class OrderDetailViewModel {
    private(set) var state: OrderDetailViewState = .loading
    private let repo: OrderRepository

    init(repo: OrderRepository) { self.repo = repo }

    func load(id: OrderID) async {
        state = .loading
        switch await repo.get(id: id) {
        case .success(let order): state = .loaded(order)
        case .failure(let error): state = .error(error)
        }
    }
}
```

**Write UI state on the main actor, not from inside the actor call.** The repository returns a value; the `@MainActor` caller assigns it. A repository that reaches back to mutate view state is the bug this map exists to prevent.

## `@MainActor` discipline

The rule that gets violated most: **don't scatter `Task { @MainActor in }` through view bodies.** Structure the flow so the main-actor function awaits and assigns on return.

```swift
// Good — the view's lifecycle owns the task, cancellation is automatic
.task { await viewModel.load(id: id) }

// Avoid — detached from the view's lifecycle, and the hop is manual
.onAppear {
    Task { @MainActor in
        viewModel.state = .loaded(await repo.load(id: id))
    }
}
```

## Cancellation contract

- `.task { }` and `.task(id:)` cancel when the view disappears or the id changes. **Use them; don't hand-roll a `Task` in `onAppear`.**
- A cancelled `Task` **does not throw on its own** — the awaiting function has to check. Put `try Task.checkCancellation()` at the top of every loop iteration that does real work.
- **Never swallow `CancellationError`.** `catch { state = .error(...) }` on a cancelled screen paints a visible error banner over a screen the user already left. Catch it separately and `return`:

```swift
do { state = .loaded(try await repo.load(id: id)) }
catch is CancellationError { return }
catch { state = .error(error) }
```

`swift-style` states the same rule from the error-contract side. It's the most common concurrency bug in this codebase.

## Approachable concurrency (Swift 6.2)

App modules opt into the `ApproachableConcurrency` upcoming feature — single-threaded by default, so ordinary code doesn't need isolation annotations. The consequence: **offloading is explicit**. Mark CPU-bound work with `@concurrent`:

```swift
@concurrent func parseLargeJSON(_ data: Data) throws -> ParsedModel {
    try JSONDecoder().decode(ParsedModel.self, from: data)
}
```

If a module hasn't opted in, don't add `@concurrent` to it — the attribute means something different under the older defaults.

## Hard nos

- **No `Task.detached`** without a documented reason. It drops priority, actor context, and task-locals — usually silently.
- **No `DispatchQueue.main.async`** in new code. Isolate the surrounding function `@MainActor`, or `await MainActor.run { }` if you can't.
- **No `@unchecked Sendable`** or `nonisolated(unsafe)` without a written invariant in a comment saying what makes it safe.
- **No `semaphore.wait()` on the main thread**, and no synchronous bridges out of async code (`Task { }.result.get()` from a sync context).
- **No locks inside an `actor`** — the actor already is the lock.
- **No casual Combine ↔ concurrency bridging.** `AsyncPublisher` is fine for consuming a publisher once; for two-way state, pick one model per feature.
