---
name: ios-di
description: Dependency injection patterns used in this project — composition root + constructor injection, protocol-oriented design, testable factories, and how DI fits with SwiftUI / @Observable. Load when adding a new type that needs dependencies, wiring a repository, setting up previews, writing tests, or debugging a DI-related crash.
---

# Dependency injection (iOS)

## The approach

**Composition root + constructor injection via protocols.** No DI container library by default. If we outgrow this, `swift-dependencies` or `Factory` are the two options we'd consider — but start simple.

Why:
- Explicit dependencies — a type's initializer lists everything it needs.
- Testability — pass fakes to the initializer; no global state to stub.
- No magic — works with Swift 6 strict concurrency, no runtime reflection.
- SwiftUI-friendly — `@Observable` view models are constructed by the root view that hosts them.

## The shape

```swift
// A DIContainer assembled at app startup. Single source of truth for "how live objects are built."
struct DIContainer {
    let apiClient: APIClient
    let orderRepository: OrderRepository

    static let live: DIContainer = {
        let api = LiveAPIClient(baseURL: Env.apiBaseURL)
        return DIContainer(
            apiClient: api,
            orderRepository: LiveOrderRepository(client: api)
        )
    }()
}

// Factory methods on the container construct things that need more context.
extension DIContainer {
    func makeOrderListViewModel() -> OrderListViewModel {
        OrderListViewModel(
            getOrders: GetOrdersUseCase(orders: orderRepository)
        )
    }

    func makeOrderDetailViewModel(id: OrderID) -> OrderDetailViewModel {
        OrderDetailViewModel(
            id: id,
            getOrder: GetOrderUseCase(orders: orderRepository),
            submit: SubmitOrderUseCase(orders: orderRepository)
        )
    }
}
```

The root view receives the container — either as an environment value or a plain property:

```swift
@main
struct MyApp: App {
    let container: DIContainer = .live

    var body: some Scene {
        WindowGroup {
            AppRootView(container: container)
                .environment(\.diContainer, container)  // optional, for deeper views
        }
    }
}

private struct DIContainerKey: EnvironmentKey {
    static let defaultValue: DIContainer = .live
}

extension EnvironmentValues {
    var diContainer: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}
```

## Protocols for testability

Every collaborator used by a use case or view model is a **protocol**. Implementations live in `Data/` (`Live…`) or in tests (`Mock…` / `Stub…`).

```swift
protocol OrderRepository: Sendable {
    func get(id: OrderID) async throws -> Order
}

// Data/
final class LiveOrderRepository: OrderRepository { /* ... */ }

// Tests/
final class StubOrderRepository: OrderRepository {
    let result: Result<Order, Error>
    func get(id: OrderID) async throws -> Order { try result.get() }
}
```

## Rules

- **No singletons.** `DIContainer.live` is the only top-level shared instance. Don't add `static let shared` elsewhere.
- **No service locator.** Don't pass the whole container into a view model; give it just the use cases it needs.
- **Initializer injection.** Every view model / use case / repository has an initializer that takes all its dependencies. No `lateinit`-style setters.
- **Constructor parameters are protocols**, not concrete types — unless the concrete type is already in the `Domain` layer (a plain struct).

## View models and views

A stateful `…RootView` creates its view model from the container:

```swift
struct OrderListRootView: View {
    @State private var model: OrderListViewModel

    init(container: DIContainer) {
        _model = State(initialValue: container.makeOrderListViewModel())
    }

    var body: some View { /* ... */ }
}
```

Don't construct view models inside a stateless child view.

## For previews and tests

Previews should use an in-memory container or direct stubs:

```swift
extension DIContainer {
    static func preview(
        orders: OrderRepository = StubOrderRepository(result: .success(.sample))
    ) -> DIContainer {
        DIContainer(
            apiClient: StubAPIClient(),
            orderRepository: orders
        )
    }
}

#Preview {
    OrderListRootView(container: .preview())
}
```

For unit tests, build the view model directly with stubs — you usually don't need the full container.

## When to graduate to a DI library

Consider `swift-dependencies` or `Factory` when:
- You have > ~30 distinct dependencies and the container is hard to read.
- You want per-test overrides without passing a container around.
- You're already using TCA (which uses `swift-dependencies` natively).

Don't introduce one just because the app is growing — the plain pattern scales further than people expect.

## Common pitfalls

- **Creating a view model in a stateless view.** The view should receive the model or values from its container.
- **Passing `DIContainer` to a view model.** The view model should only see the use cases it uses.
- **Global `EnvironmentValues` as hidden DI.** Environment is for UI concerns (theme, locale). Don't stash business services there.
- **Forgetting `@MainActor` on a view model.** Leads to data races under Swift 6 strict concurrency.
