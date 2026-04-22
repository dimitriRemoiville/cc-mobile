---
name: clean-architecture
description: How MVVM + Clean Architecture is applied in this Kotlin + Compose codebase. Load when designing a new feature, deciding where code belongs, adding a repository or use case, or reviewing layer boundaries.
---

# Clean Architecture in this project

## The three layers

```
presentation  ─ Compose + ViewModel + UiState. Knows Android & Compose.
     ↓
   domain    ─ Pure Kotlin. Business rules. No Android, no Compose, no Retrofit, no Room.
     ↑
    data     ─ Repository implementations. Knows Retrofit, Room, DataStore, etc.
```

**Dependency rule:** `presentation → domain ← data`. Arrows never reverse. Both outer layers depend on `domain`; `domain` depends on nothing but Kotlin + coroutines.

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
    suspend fun getOrder(id: OrderId): Result<Order>
    fun observeOrders(): Flow<List<Order>>
}

// domain/usecase/SubmitOrderUseCase.kt
class SubmitOrderUseCase @Inject constructor(
    private val orders: OrderRepository,
    private val clock: Clock,
) {
    suspend operator fun invoke(draft: OrderDraft): Result<Order> { ... }
}
```

## Data layer

What lives here:
- **Remote** — Retrofit service + DTOs (with `@Serializable` or Moshi annotations).
- **Local** — Room `@Entity`, `@Dao`.
- **Mappers** — DTO/Entity ↔ domain model. One-way conversion functions, no shared interface required.
- **Repository implementation** — implements the domain interface.

```kotlin
// data/remote/OrderApi.kt
interface OrderApi {
    @GET("orders/{id}")
    suspend fun getOrder(@Path("id") id: String): OrderDto
}

// data/mapper/OrderMapper.kt
fun OrderDto.toDomain(): Order = Order(id = OrderId(id), ...)

// data/repository/OrderRepositoryImpl.kt
class OrderRepositoryImpl @Inject constructor(
    private val api: OrderApi,
    private val dao: OrderDao,
) : OrderRepository {
    override suspend fun getOrder(id: OrderId): Result<Order> =
        runCatching { api.getOrder(id.raw).toDomain() }
}
```

## Presentation layer

What lives here:
- **Composables** — the Route/Screen split described in the `compose-ui` skill.
- **ViewModels** — expose `StateFlow<UiState>` and `Channel<UiEvent>`, call use cases (not repositories directly, unless the action is genuinely trivial).
- **UiState / UiAction / UiEvent** — the contract between Composable and ViewModel.
- **Navigation** — route declarations, nav graph composition.

```kotlin
@HiltViewModel
class OrderViewModel @Inject constructor(
    private val submit: SubmitOrderUseCase,
) : ViewModel() {
    private val _state = MutableStateFlow<OrderUiState>(OrderUiState.Loading)
    val state: StateFlow<OrderUiState> = _state.asStateFlow()

    private val _events = Channel<OrderEvent>(Channel.BUFFERED)
    val events = _events.receiveAsFlow()

    fun onAction(action: OrderAction) { ... }
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

- **Start with packages** inside `:app`: `feature_x.data`, `feature_x.domain`, `feature_x.presentation`.
- **Promote to modules** when: the feature is big, has its own team, or you want build-time isolation. Common split: `:core:domain`, `:core:data`, `:feature:orders`.
- Don't over-modularize early — module boundaries are expensive to rearrange.

## Feature checklist

When adding a feature, every item below should exist:

- [ ] Domain model in `domain/model/`
- [ ] Repository interface in `domain/repository/`
- [ ] Use case(s) in `domain/usecase/` (if warranted)
- [ ] DTO + mapper in `data/remote/` and `data/mapper/`
- [ ] Retrofit service method in `data/remote/`
- [ ] RepositoryImpl in `data/repository/`
- [ ] Hilt `@Module` in `data/di/`
- [ ] UiState + UiAction + UiEvent in `presentation/<feature>/`
- [ ] ViewModel with `@HiltViewModel`
- [ ] Route + Screen composables + at least one `@Preview`
- [ ] Nav destination wired in
- [ ] Unit tests for use case, mapper, ViewModel
- [ ] Compose UI test for the screen (at least happy path)
