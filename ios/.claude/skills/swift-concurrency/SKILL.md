---
name: swift-concurrency
description: Swift 6 strict concurrency patterns — actors, Sendable, @MainActor discipline, structured concurrency, cancellation, task trees, AsyncSequence, avoiding data races. Load whenever touching async code, cross-actor boundaries, or long-running work.
---

# Swift concurrency

Baseline: Swift 6 with strict concurrency enabled. Build failures here are design failures — don't silence with `@unchecked Sendable` unless you understand why.

## Isolation model

- Views (`View`), ViewModels, coordinators -> `@MainActor`.
- Repositories -> `actor`.
- Pure value-types crossing boundaries -> `Sendable`.
- Reference types crossing boundaries -> actor, final class with a lock, or `@unchecked Sendable` + a documented invariant.

```swift
actor OrderRepository {
    private var cache: [String: Order] = [:]
    private let client: APIClient

    init(client: APIClient) { self.client = client }

    func load(id: String) async throws -> Order {
        if let cached = cache[id] { return cached }
        let order = try await client.fetch(Order.self, id: id)
        cache[id] = order
        return order
    }
}

@Observable @MainActor
final class OrderDetailViewModel {
    private let repo: OrderRepository
    var state: ViewState = .idle

    init(repo: OrderRepository) { self.repo = repo }

    func load(id: String) async {
        state = .loading
        do { state = .ready(try await repo.load(id: id)) }
        catch is CancellationError { return }
        catch { state = .error(error) }
    }
}
```

## Sendable

`struct` of `Sendable` members is automatically `Sendable`. Mark explicitly when you cross a module boundary:

```swift
public struct Order: Sendable, Equatable, Identifiable {
    public let id: String
    public let totalCents: Int
}
```

For closures, `@Sendable` both documents and enforces:

```swift
func run(_ work: @Sendable () async -> Void) async { await work() }
```

## @MainActor discipline

- The view and its state are main-actor.
- The moment you hop off the main actor, you're in another isolation domain. You cannot mutate view state from inside an `actor` call — return the value and let the main-actor caller write it.
- Avoid `Task { @MainActor in }` scattered throughout the body — structure the flow so the main actor calls into a repo and writes state on return:

```swift
// Good
.task { await viewModel.load(id: id) }

// Avoid
.onAppear {
    Task { @MainActor in
        let v = await repo.load(id: id)
        viewModel.state = .ready(v)
    }
}
```

## Structured concurrency

Use `async let` and `TaskGroup` for parallel work; avoid `Task { ... }` when you can, because it detaches from cancellation.

```swift
func loadDashboard() async throws -> Dashboard {
    async let orders = repo.fetchOrders()
    async let balance = repo.fetchBalance()
    async let notifications = repo.fetchNotifications()
    return Dashboard(
        orders: try await orders,
        balance: try await balance,
        notifications: try await notifications,
    )
}
```

For a dynamic set of parallel tasks:

```swift
try await withThrowingTaskGroup(of: Order.self) { group in
    for id in ids { group.addTask { try await repo.load(id: id) } }
    var result: [Order] = []
    for try await order in group { result.append(order) }
    return result
}
```

## Cancellation

- Every `async` function that does meaningful work should respect cancellation via `try Task.checkCancellation()` at loop boundaries.
- `URLSession.data(for:)`, most `AsyncSequence`, and standard library awaits are already cooperative.
- A `Task` cancelled by the caller **does not throw** unless the awaiting function checks. Don't swallow `CancellationError` silently — re-throw or `return`.

```swift
for id in ids {
    try Task.checkCancellation()
    try await repo.load(id: id)
}
```

In SwiftUI, `.task(id:)` auto-cancels when the id changes or view disappears. Use it.

## AsyncSequence

For push-style data (sockets, Combine bridges, Core Motion), expose `AsyncStream` or `AsyncSequence`:

```swift
actor OrderLiveFeed {
    func stream() -> AsyncStream<OrderEvent> {
        AsyncStream { continuation in
            let subscription = source.subscribe { continuation.yield($0) }
            continuation.onTermination = { _ in subscription.cancel() }
        }
    }
}
```

Consume:

```swift
.task {
    for await event in repo.stream() { viewModel.apply(event) }
}
```

## Swift 6.2 approachable concurrency

- A module can opt into "single-threaded by default" via the `ApproachableConcurrency` upcoming feature; most of our app modules do.
- Mark CPU-bound offloading **explicitly** with `@concurrent`:

```swift
@concurrent func parseLargeJSON(_ data: Data) throws -> ParsedModel {
    try JSONDecoder().decode(ParsedModel.self, from: data)
}
```

- `@MainActor` types can conform to protocols with `isolated` conformance when needed (e.g., `Equatable` with main-actor captured state).

## Avoiding traps

- `Task { [weak self] in ... }` is rarely right. Actors don't hold `self` across `await` the way classes do; prefer structured tasks owned by the view's lifecycle.
- Don't bridge Combine and Swift Concurrency casually. `AsyncPublisher` is fine for consuming a publisher once; for two-way state, pick one model.
- Don't catch every error with `catch {}`. Catch `is CancellationError` separately to not break cancellation propagation.
- Don't lock inside an `actor` — defeats the purpose.

## Hard nos

- No `Task.detached { ... }` without a documented reason (detached tasks don't inherit priority, actor, or task-local values).
- No `DispatchQueue.main.async` in new code — use `await MainActor.run { ... }` or, better, isolate the surrounding function.
- No `@unchecked Sendable` without a written invariant in a comment.
- No `nonisolated(unsafe)` without the same.
- No `semaphore.wait()` on the main thread.
- No `runBlocking`-style synchronous bridges from async code (`Task { ... }.result.get()` synchronously).
