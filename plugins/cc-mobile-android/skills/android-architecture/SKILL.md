---
name: android-architecture
description: How MVVM + Clean Architecture is applied in this Kotlin + Compose codebase. Load when designing a new feature, deciding where code belongs, adding a repository or use case, or reviewing layer boundaries.
---

# Android architecture (MVVM + Clean)

## The three layers

```
ui        ─ Compose + ViewModel + UiState. Knows Android & Compose.
   ↓
domain    ─ Pure Kotlin. Business rules. No Android, no Compose, no Retrofit, no Room.
   ↑
data      ─ Repository implementations. Knows Retrofit, Room, DataStore, etc.
```

**Dependency rule:** `ui → domain ← data`. Arrows never reverse. Both outer layers depend on `domain`; `domain` depends on nothing but Kotlin + coroutines.

**Per feature, not global.** These three are the layers *within* a feature: `<feature>/ui/`, `<feature>/domain/`, `<feature>/data/`. The skeleton uses `ui/` (not `presentation/`) — same idea, fewer letters, matches `core/ui/theme/` naming. Cross-feature plumbing of the same layers lives under `core/{ui,domain,data}/`.

## Domain layer

What lives here:
- **Models** — plain Kotlin data classes. No annotations from Android, Room, Moshi, or Retrofit.
- **Repository interfaces** — describe what data the domain needs, in domain types.
- **Use cases** — one class per business action. Injectable. Suspend or return `Flow`.

```kotlin
// domain/model/Order.kt
data class Order(val id: OrderId, val items: List<OrderItem>, val total: Money)

// domain/repository/OrderRepository.kt
interface OrderRepository {
    suspend fun getOrder(id: OrderId): Outcome<Order>
    fun observeOrders(): Flow<List<Order>>
}

// domain/usecase/SubmitOrderUseCase.kt
class SubmitOrderUseCase @Inject constructor(
    private val orders: OrderRepository,
    private val clock: Clock,
) {
    suspend operator fun invoke(draft: OrderDraft): Outcome<Order> { ... }
}
```

`Outcome<T>` is the project's canonical sealed result, defined once in `core/domain/Outcome.kt` (see `android-app-skeleton`). Domain-facing signatures never use `Result<T>`.

## Data layer

What lives here:
- **Remote** — Retrofit service + DTOs (with `@Serializable` or Moshi annotations).
- **Local** — Room `@Entity`, `@Dao`.
- **Mappers** — DTO/Entity ↔ domain model. One-way conversion functions, no shared interface required.
- **Repository implementation** — implements the domain interface.

```kotlin
// <feature>/data/remote/OrderDto.kt — DTO + colocated mapper
@Serializable
data class OrderDto(val id: String, /* ... */)

fun OrderDto.toDomain(): Order = Order(id = OrderId(id), /* ... */)

// <feature>/data/remote/OrderApi.kt
interface OrderApi {
    @GET("orders/{id}")
    suspend fun getOrder(@Path("id") id: String): OrderDto
}

// <feature>/data/repository/OrderRepositoryImpl.kt
class OrderRepositoryImpl @Inject constructor(
    private val api: OrderApi,
    private val dao: OrderDao,
) : OrderRepository {
    override suspend fun getOrder(id: OrderId): Outcome<Order> =
        runCatching { api.getOrder(id.raw).toDomain() }.toOutcome(::toDomainError)
}
```

The mapper sits in `OrderDto.kt` next to the DTO it transforms. Promote to a `<feature>/data/mapper/` package only when several DTOs map to the same domain type and the shared file would clarify ownership — see the feature checklist below.

`toOutcome` and `toDomainError` are scaffolded once in `core/data/network/Outcomes.kt` (see `android-app-skeleton` → "core/data/"). Every repository goes through them — the helper rethrows `CancellationException`, which the open-coded `runCatching { ... }.fold(...)` shape silently swallows.

## UI layer (`<feature>/ui/`)

What lives here:
- **Composables** — the Route/Screen split described in the `compose-ui` skill.
- **ViewModels** — expose `StateFlow<UiState>` and (when needed) `Channel<UiEvent>` for one-shot effects; call use cases (not repositories directly, unless the action is genuinely trivial).
- **UiState / UiEvent** — the contract between Composable and ViewModel. **User actions are discrete public functions on the ViewModel** (`fun submit(...)`, `fun retry()`), and the Composable takes one lambda per action — the shape Google's [Now in Android](https://github.com/android/nowinandroid) uses, and the canonical MVVM shape. Escalate to a sealed `UiAction` + a single `onAction(action: UiAction)` callback only when the screen has ≥5 distinct interactions and a flat lambda surface would be unwieldy. That's an MVI shape; this project is MVVM by default.
- **Navigation** — route declarations live with the feature; the top-level `AppNavGraph` in `core/navigation/` composes them.

```kotlin
@HiltViewModel
class OrderViewModel @Inject constructor(
    private val submit: SubmitOrderUseCase,
    private val analytics: AnalyticsTracker,
) : ViewModel() {
    private val _state = MutableStateFlow<OrderUiState>(OrderUiState.Loading)
    val state: StateFlow<OrderUiState> = _state.asStateFlow()

    private val _events = Channel<OrderEvent>(Channel.BUFFERED)
    val events = _events.receiveAsFlow()

    init { analytics.track(AnalyticsEvent.OrderViewed) }

    fun submit(draft: OrderDraft) { ... }
    fun retry() { ... }
}
```

## When to add a use case

**Add one when:**
- There's business logic (validation, composition of multiple repositories, derived computation).
- Multiple ViewModels will call the same operation.
- The operation has testable branches that aren't interesting to test via a ViewModel.

**Skip it when:**
- The ViewModel would literally just call `repository.foo()` and return. Inject the repository directly in that case, but only if the rest of the codebase is consistent about this.

## Module or package?

- **Start with packages** inside `:app`, **feature-first**: `feature_x/{ui,domain,data}/`. Cross-feature plumbing under `core/` (see `android-app-skeleton` for the canonical layout).
- **Promote to modules** when: the feature is big, has its own team, or you want build-time isolation. Common split: `:core:domain`, `:core:data`, `:feature:orders`. Feature-first packages promote cleanly to feature-first modules — that's the main reason to start this way.
- Don't over-modularize early — module boundaries are expensive to rearrange.

## Feature checklist

When adding a feature, every item below should exist:

- [ ] Domain model in `<feature>/domain/model/`
- [ ] Repository interface in `<feature>/domain/repository/`
- [ ] Use case(s) in `<feature>/domain/usecase/` (if warranted — see "When to add a use case")
- [ ] DTO in `<feature>/data/remote/` (mapping function colocated with the DTO is fine; promote to a `mapper/` package only when several DTOs map to the same domain type)
- [ ] Retrofit service method in `<feature>/data/remote/`
- [ ] RepositoryImpl in `<feature>/data/repository/` (consumes `RemoteDataSource`-style helpers from `core/data/network/`; never `runCatching { ... }.fold(...)` open-coded)
- [ ] Hilt `@Module` in `<feature>/data/di/`
- [ ] UiState + UiAction + UiEvent in `<feature>/ui/`
- [ ] ViewModel with `@HiltViewModel`
- [ ] Route + Screen composables + at least one `@Preview`
- [ ] Nav destination wired in (`core/navigation/AppNavGraph.kt`)
- [ ] Unit tests for use case, mapper (if extracted), ViewModel
- [ ] Compose UI test for the screen (at least happy path)
