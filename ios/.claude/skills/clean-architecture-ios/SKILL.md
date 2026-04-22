---
name: clean-architecture-ios
description: How MVVM + Clean Architecture is applied in this Swift + SwiftUI codebase. Load when designing a new feature, deciding where code belongs, adding a repository or use case, or reviewing layer boundaries.
---

# Clean Architecture in this project

## The three layers

```
Presentation  — SwiftUI views + @Observable ViewModels + ViewState. Knows SwiftUI.
      ↓
   Domain     — Pure Swift. Structs, enums, protocols, use cases. No SwiftUI / UIKit / URLSession / SwiftData.
      ↑
    Data      — Repository implementations. Knows URLSession, SwiftData, Keychain, etc.
```

**Dependency rule:** `Presentation → Domain ← Data`. Arrows never reverse. Both outer layers depend on `Domain`; `Domain` depends on nothing outside `Foundation` + `Swift`.

## Domain layer

What lives here:
- **Models** — plain Swift structs / enums. `Sendable`, `Equatable`, usually `Hashable`. No framework annotations.
- **Repository protocols** — describe what data the domain needs, in domain types.
- **Use cases** — one type per business action. Async. Injected dependencies are protocols.

```swift
// Domain/Model/Order.swift
struct Order: Equatable, Sendable {
    let id: OrderID
    let items: [OrderItem]
    let total: Money
}

// Domain/Repository/OrderRepository.swift
protocol OrderRepository: Sendable {
    func get(id: OrderID) async throws -> Order
    func observe() -> AsyncStream<[Order]>
}

// Domain/UseCase/SubmitOrderUseCase.swift
struct SubmitOrderUseCase {
    private let orders: OrderRepository
    private let now: () -> Date

    init(orders: OrderRepository, now: @escaping () -> Date = Date.init) {
        self.orders = orders
        self.now = now
    }

    func callAsFunction(_ draft: OrderDraft) async throws -> Order { /* ... */ }
}
```

## Data layer

What lives here:
- **Remote** — URLSession-backed client + DTOs (`Codable`).
- **Local** — SwiftData models + persistence wrappers.
- **Mappers** — DTO / SwiftData model ↔ domain model. One-way functions.
- **Repository implementations** — conform to the domain protocol.

```swift
// Data/Remote/OrderDTO.swift
struct OrderDTO: Decodable {
    let id: String
    let items: [OrderItemDTO]
    let totalCents: Int
    let createdAt: String
}

// Data/Mapper/OrderMapper.swift
extension OrderDTO {
    func toDomain() -> Order {
        Order(
            id: OrderID(id),
            items: items.map { $0.toDomain() },
            total: .cents(totalCents)
        )
    }
}

// Data/Repository/LiveOrderRepository.swift
final class LiveOrderRepository: OrderRepository {
    private let client: APIClient

    init(client: APIClient) { self.client = client }

    func get(id: OrderID) async throws -> Order {
        do {
            let dto: OrderDTO = try await client.get("/orders/\(id.raw)")
            return dto.toDomain()
        } catch let error as URLError {
            throw DomainError.network(code: error.code.rawValue)
        } catch is DecodingError {
            throw DomainError.invalidResponse
        }
    }
}
```

## Presentation layer

What lives here:
- **Views** — the Root / Stateless split described in the `swiftui-views` skill.
- **ViewModels** — `@Observable @MainActor final class`, exposing `ViewState`, calling use cases.
- **ViewState / ViewAction / ViewEvent** — the contract between view and view model.
- **Navigation** — route enums, nav-stack composition.

## When to add a use case

**Add one when:**
- There's business logic (validation, composition of multiple repositories, derived computation).
- Multiple view models call the same operation.
- The operation has testable branches that aren't interesting to test via a view model.

**Skip it when:**
- The view model would literally just call `repository.foo()` and return. Inject the repository directly in that case — but only if the rest of the codebase is consistent about this.

## Folder or SPM package?

- **Start with folders** inside the app target: `Feature_X/Data`, `Feature_X/Domain`, `Feature_X/Presentation`.
- **Promote to SPM packages** when: the feature is large, build time is hurting, or you want enforced module boundaries. Typical splits: `Core`, `Networking`, `Persistence`, `Feature_X`.
- Don't over-modularize early — package boundaries are expensive to rearrange in Xcode.

## Feature checklist

When adding a feature, every item below should exist:

- [ ] Domain model in `Domain/Model/`
- [ ] Repository protocol in `Domain/Repository/`
- [ ] Use case(s) in `Domain/UseCase/` (if warranted)
- [ ] DTO + mapper in `Data/Remote/` and `Data/Mapper/`
- [ ] API endpoint definition in `Data/Remote/`
- [ ] `Live…Repository` (or named) in `Data/Repository/`
- [ ] Registered in composition root / DI container
- [ ] ViewState + ViewAction + ViewEvent in `Presentation/<Feature>/`
- [ ] `@Observable` ViewModel with constructor-injected dependencies
- [ ] Root + Stateless views + at least one `#Preview`
- [ ] Navigation destination wired into `AppRoute`
- [ ] Unit tests for use case, mapper, view model
- [ ] UI test or snapshot test for the view (at least happy path)
