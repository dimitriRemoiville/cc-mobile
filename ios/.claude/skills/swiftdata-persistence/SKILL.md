---
name: swiftdata-persistence
description: SwiftData patterns for this iOS project — @Model entities, ModelContext/ModelContainer, @Query in SwiftUI, migrations via VersionedSchema, and protocol-wrapped testability. Load whenever writing or reviewing code under `data/persistence/`.
---

# SwiftData persistence

## Model

```swift
import SwiftData

@Model
final class Order {
    @Attribute(.unique) var id: String
    var customerId: String
    var totalCents: Int
    var status: OrderStatus
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \LineItem.order)
    var lineItems: [LineItem] = []

    init(id: String, customerId: String, totalCents: Int, status: OrderStatus, createdAt: Date) {
        self.id = id
        self.customerId = customerId
        self.totalCents = totalCents
        self.status = status
        self.createdAt = createdAt
    }
}

enum OrderStatus: String, Codable { case pending, paid, cancelled }
```

- Always annotate the stable identity column with `@Attribute(.unique)`.
- `@Relationship` with explicit `deleteRule` and `inverse` — missing `inverse` causes orphans.
- Enums: `Codable` + `RawRepresentable` store cleanly; avoid associated values as stored attributes.

## Container

One `ModelContainer` per process, owned at app launch:

```swift
@main
struct AppEntry: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Order.self, LineItem.self,
                migrationPlan: AppMigrationPlan.self,
                configurations: ModelConfiguration(
                    schema: Schema(versionedSchema: AppSchemaV2.self),
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .automatic,
                ),
            )
        } catch {
            fatalError("Failed to build ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(container)
    }
}
```

## Repository protocol (testable boundary)

SwiftData types (`ModelContext`, `@Query`) are UI-friendly but cross-cutting business logic needs a protocol:

```swift
protocol OrderRepository: Sendable {
    func upsert(_ order: OrderDTO) async throws
    func orders(for customerId: String) async throws -> [OrderDTO]
    func observe(customerId: String) -> AsyncStream<[OrderDTO]>
}

actor SwiftDataOrderRepository: OrderRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func upsert(_ order: OrderDTO) async throws {
        let descriptor = FetchDescriptor<Order>(predicate: #Predicate { $0.id == order.id })
        if let existing = try context.fetch(descriptor).first {
            existing.apply(order)
        } else {
            context.insert(Order(dto: order))
        }
        try context.save()
    }
    // ...
}
```

- `actor` enforces serialized access to the `ModelContext` (SwiftData contexts are not `Sendable`).
- Use `#Predicate<Order>` macros, not `NSPredicate`.

## @Query in SwiftUI

Direct `@Query` is fine for leaf screens that are a thin list:

```swift
struct OrdersList: View {
    @Query(sort: \Order.createdAt, order: .reverse) private var orders: [Order]
    var body: some View { List(orders) { OrderRow(order: $0) } }
}
```

For filtered queries, construct once with `@Query(filter:)` or a dynamic `FetchDescriptor` via `@Query` initializer.

Non-trivial screens route through the ViewModel + repository, not `@Query`.

## Migrations

Model each schema version as `VersionedSchema`, then a `SchemaMigrationPlan`:

```swift
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [Order.self, LineItem.self]
}

enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] = [Order.self, LineItem.self]
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [AppSchemaV1.self, AppSchemaV2.self]
    static var stages: [MigrationStage] = [migrateV1toV2]

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: AppSchemaV1.self,
        toVersion: AppSchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            let orders = try context.fetch(FetchDescriptor<Order>())
            for order in orders where order.status == .pending && order.createdAt < .oldEnoughToAbandon {
                order.status = .cancelled
            }
            try context.save()
        },
    )
}
```

Use `.lightweight` when the only change is additive. Use `.custom` for transforms.

## Testing

```swift
import SwiftData
import Testing

@Suite(.serialized)
struct OrderRepositoryTests {
    func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Order.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true),
        )
        return ModelContext(container)
    }

    @Test func upsertRoundTrip() async throws {
        let context = try makeContext()
        let sut = SwiftDataOrderRepository(context: context)
        let dto = OrderDTO.sample
        try await sut.upsert(dto)
        #expect(try await sut.orders(for: dto.customerId).count == 1)
    }
}
```

`isStoredInMemoryOnly: true` keeps tests hermetic. Don't rely on file cleanup.

## Hard nos

- No passing `ModelContext` across actors. Build a new one from the container in each isolation domain.
- No `try! context.save()` in shipping code. Propagate.
- No mutating `@Model` properties off the main actor while also observing them on the main actor — use an actor repo or `.mainContext`.
- No relationship without `inverse`.
- No SwiftData usage in Domain/Data protocols. Domain speaks DTOs.
