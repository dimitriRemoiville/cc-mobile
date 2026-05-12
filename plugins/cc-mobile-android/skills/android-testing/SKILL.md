---
name: android-testing
description: Testing patterns used in this project — JUnit + MockK unit tests, `runTest` for coroutines, Turbine for Flow, Compose UI tests with `createComposeRule`, and Hilt-aware instrumentation tests. Load when writing, updating, or debugging tests of any kind.
---

# Testing playbook

## Dependencies to have in the catalog

- `junit`, `kotlin-test`
- `kotlinx-coroutines-test`
- `mockk`
- `turbine`
- `androidx.compose.ui:ui-test-junit4` + `ui-test-manifest`
- `androidx.hilt:hilt-android-testing` + `hilt-compiler` (`ksp`)
- `androidx.arch.core:core-testing` (for `InstantTaskExecutorRule` if any LiveData sneaks in)

## Where tests live

```
src/test/                 # JVM unit tests — fast, no emulator
src/androidTest/          # Instrumented — emulator/device, Compose UI tests
```

## Use case tests (pure JVM)

```kotlin
class SubmitOrderUseCaseTest {
    private val orders: OrderRepository = mockk()
    private val clock: Clock = FakeClock("2026-04-22T00:00:00Z")
    private val submit = SubmitOrderUseCase(orders, clock)

    @Test
    fun `returns Success when repository accepts the order`() = runTest {
        val draft = OrderDraft(items = listOf(item()))
        coEvery { orders.create(draft) } returns Outcome.Success(ORDER)

        val result = submit(draft)

        assertThat(result).isInstanceOf(Outcome.Success::class.java)
    }

    @Test
    fun `returns Failure when repository returns error`() = runTest {
        coEvery { orders.create(any()) } returns Outcome.Failure(DomainError.Network())

        val result = submit(OrderDraft(emptyList()))

        assertThat(result).isEqualTo(Outcome.Failure(DomainError.Network()))
    }
}
```

Repository / use-case mocks always return `Outcome.Success(...)` or `Outcome.Failure(DomainError.X(...))` — not `Result.success` / `Result.failure`. See `kotlin-style` for why.

## ViewModel tests

```kotlin
@OptIn(ExperimentalCoroutinesApi::class)
class OrderViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val submit: SubmitOrderUseCase = mockk()
    private lateinit var viewModel: OrderViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        viewModel = OrderViewModel(submit)
    }

    @After fun tearDown() { Dispatchers.resetMain() }

    @Test
    fun `state transitions Loading -> Success`() = runTest(dispatcher) {
        coEvery { submit(any()) } returns Outcome.Success(ORDER)

        viewModel.state.test {
            assertThat(awaitItem()).isEqualTo(OrderUiState.Loading)
            viewModel.onAction(OrderAction.Submit(DRAFT))
            assertThat(awaitItem()).isInstanceOf(OrderUiState.Success::class.java)
        }
    }
}
```

Rules:
- **Always** set + reset `Dispatchers.Main`.
- `StandardTestDispatcher` (not `UnconfinedTestDispatcher`) unless you have a specific reason.
- Use **Turbine** — don't poll `viewModel.state.value`.

## Flow tests with Turbine

```kotlin
flow.test {
    assertThat(awaitItem()).isEqualTo(first)
    assertThat(awaitItem()).isEqualTo(second)
    awaitComplete()
}
```

- `cancelAndIgnoreRemainingEvents()` when you don't care what happens after the assertion you care about.
- `expectNoEvents()` when asserting something did **not** emit.

## Fakes vs mocks

Default to **fakes** for classes with >2 methods or non-trivial behavior. Fakes are cheaper to maintain than 20 `coEvery` lines.

```kotlin
class FakeOrderRepository : OrderRepository {
    var orders: Map<OrderId, Order> = emptyMap()
    override suspend fun getOrder(id: OrderId): Outcome<Order> =
        orders[id]?.let { Outcome.Success(it) }
            ?: Outcome.Failure(DomainError.NotFound())
}
```

Mock only:
- Generated services (Retrofit interfaces, Room DAOs).
- Single-method lambdas / callbacks.
- Collaborators being used for exactly one call in one test.

## Compose UI tests

```kotlin
class OrderScreenTest {
    @get:Rule val composeRule = createComposeRule()

    @Test fun `shows order id in Success state`() {
        composeRule.setContent {
            AppTheme {
                OrderScreen(
                    state = OrderUiState.Success(fakeOrder(id = "ABC")),
                    onBack = {},
                    onAction = {},
                )
            }
        }

        composeRule.onNodeWithText("Order ABC").assertIsDisplayed()
    }
}
```

Prefer **semantic matchers** (`onNodeWithText`, `onNodeWithContentDescription`) over `testTag`. Only add a `testTag` when there's no natural semantic.

## Hilt instrumentation tests

```kotlin
@HiltAndroidTest
class OrderFlowTest {
    @get:Rule(order = 0) val hiltRule = HiltAndroidRule(this)
    @get:Rule(order = 1) val composeRule = createAndroidComposeRule<MainActivity>()

    @BindValue @JvmField
    val repo: OrderRepository = FakeOrderRepository().apply { orders = mapOf(OrderId("x") to ORDER_X) }

    @Before fun setUp() { hiltRule.inject() }

    @Test fun `user can see seeded order`() { ... }
}
```

`@BindValue` replaces the real binding for this one test.

## Run tests

```bash
./gradlew :app:testDebugUnitTest --tests 'com.example.OrderViewModelTest'
./gradlew :app:connectedDebugAndroidTest --tests 'com.example.OrderFlowTest'
```

## Don'ts

- No `Thread.sleep` or bare `delay` outside `runTest`.
- No real network in unit tests. No real Room (use `Room.inMemoryDatabaseBuilder` only if you must).
- No test depending on the order of other tests. Each test sets up its own world.
- No assertion without a message when the diff isn't obvious.
