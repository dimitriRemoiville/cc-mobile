---
name: swiftdata-persistence
description: Project-specific SwiftData conventions — the actor-wrapped repository boundary, when `@Query` is allowed in a view, the `VersionedSchema` migration policy, in-memory test containers, and the `ModelContext` isolation rules. Load whenever writing or reviewing persistence code.
---

# SwiftData (project delta)

For SwiftData fundamentals — `@Model`, `@Attribute`, `@Relationship`, `ModelContainer` / `ModelContext`, `#Predicate`, `FetchDescriptor`, `@Query`, `VersionedSchema` and `SchemaMigrationPlan` mechanics — read [Apple's SwiftData documentation](https://developer.apple.com/documentation/swiftdata). This file documents only this project's decisions. The scaffolded container and schema templates live in `${CLAUDE_PLUGIN_ROOT}/skills/ios-app-skeleton/references/optional-swiftdata.md`.

## When this applies

SwiftData, behind a repository protocol. On an existing app:

- **Core Data** (`NSManagedObject`, `.xcdatamodeld`, `NSPersistentContainer`) → skip. Migrating to SwiftData is a project, not a refactor, and Core Data still does things SwiftData can't (fine-grained fetch control, complex migrations).
- **Realm** (`import RealmSwift`) → skip; the object-DB threading model is different in kind.
- **GRDB / raw SQLite** → skip the model layer; the repository-boundary rule below still applies.
- **`UserDefaults` for structured data** → worth flagging as a correctness risk, but don't migrate unasked.

## The repository boundary

**`@Model` types never leave the data layer.** Domain code speaks `AppCore` value types; the repository maps between them. A `@Model` class reaching a view model drags SwiftData's identity, faulting, and isolation semantics into code that shouldn't know they exist.

```swift
actor SwiftDataOrderRepository: OrderRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func upsert(_ order: Order) async -> Outcome<Void> {
        let id = order.id.raw
        let descriptor = FetchDescriptor<OrderModel>(predicate: #Predicate { $0.id == id })
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.apply(order)
            } else {
                context.insert(OrderModel(order))
            }
            try context.save()
            return .success(())
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }
}
```

Two things that are easy to get wrong here:

- **`actor`, because `ModelContext` is not `Sendable`.** The actor is what serializes access. Passing a context across isolation domains is undefined behaviour, not a warning.
- **Hoist captured values out of `#Predicate`.** `$0.id == order.id.raw` fails to compile or misbehaves inside the macro; bind `let id = order.id.raw` first. This costs people an hour every time.

## `@Query` in a view

Allowed **only** on a leaf screen that is a thin list over local data with no business logic:

```swift
struct OrdersList: View {
    @Query(sort: \OrderModel.createdAt, order: .reverse) private var orders: [OrderModel]
    var body: some View { List(orders) { OrderRow(model: $0) } }
}
```

Anything with filtering logic, derived state, or a write path goes through the view model and the repository. `@Query` is a convenience for the trivial case, not an alternative architecture — and it re-introduces the `@Model`-in-the-view coupling the boundary rule exists to prevent, so keep it to screens where that's genuinely all there is.

## Migrations

Every schema change gets a new `VersionedSchema` and a `MigrationStage`, even the additive ones. `.lightweight` when the change is purely additive, `.custom` when data has to be transformed. **Never mutate an existing `VersionedSchema` in place** — shipped devices are already on it, and the container has no way to detect the change.

## Testing

In-memory containers, per test:

```swift
let container = try ModelContainer(
    for: OrderModel.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
)
let sut = SwiftDataOrderRepository(context: ModelContext(container))
```

`isStoredInMemoryOnly: true` keeps tests hermetic — don't rely on file cleanup between runs. Suites that share a container need `@Suite(.serialized)`.

Migration stages deserve their own tests: build a container on the old schema, insert representative rows, then open with the migration plan and assert the transform.

## Hard nos

- **No passing `ModelContext` across actors.** Build one from the container in each isolation domain.
- **No `try!` on `save()`** in shipping code. Propagate or map to `DomainError`.
- **No `@Relationship` without an explicit `inverse:`** — the omission silently orphans records.
- **No mutating a `@Model` off the main actor** while also observing it on the main actor.
- **No SwiftData import in `AppCore`.** The domain speaks value types; that's the whole point of the boundary.
