---
name: android-testing
description: Project-specific testing conventions on top of JUnit 4 + MockK + Turbine + Compose UI tests + Hilt-aware instrumentation. Covers `Outcome<T>` mock returns, the `AnalyticsTracker`-on-init assertion every VM test makes, the fakes-vs-mocks heuristic, and the `@BindValue` Hilt-test shortcut. Load when writing, updating, or debugging tests of any kind.
---

# Testing (project delta)

For testing fundamentals — `runTest`, `Dispatchers.setMain`, basic Turbine usage, `createComposeRule`, MockK syntax — read the [coroutines testing guide](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-test/), the [Turbine README](https://github.com/cashapp/turbine), and Google's [`testing/testing-setup` skill](https://github.com/android/skills/tree/main/testing/testing-setup). This file documents only this project's conventions.

## When this applies

JUnit 4 + MockK + Turbine + Compose UI tests + Hilt instrumentation. On an existing app:

- **JUnit 5** (`org.junit.jupiter.*`) → keep it. Don't migrate; JUnit 4 stays cleaner with `androidx.test.*` runners but JUnit 5 is fine for pure-JVM modules.
- **Mockito** (`org.mockito.*`) → adapt syntax, don't force a MockK migration.
- **Kotest** (`io.kotest.*`) → keep; assertion style differs but the Turbine / `runTest` patterns below still apply.
- **Robolectric** in unit tests → flag the slow-test cost when relevant, don't refactor.

## Outcome in mock returns

Repository / use-case mocks **always** return `Outcome.Success(...)` or `Outcome.Failure(DomainError.X(...))` — never `Result.success` / `Result.failure`. See `kotlin-style` for the rule. Common pattern:

```kotlin
coEvery { orders.create(any()) } returns Outcome.Failure(DomainError.Network())
```

## ViewModel test rules

- `StandardTestDispatcher`, **not** `UnconfinedTestDispatcher`, unless you have a specific reason.
- Always `Dispatchers.setMain(dispatcher)` in `@Before`, `Dispatchers.resetMain()` in `@After`.
- Drive the scheduler with `advanceUntilIdle()` and `runTest(dispatcher)`. Don't rely on immediate execution.
- Collect state with **Turbine** (`flow.test { awaitItem() }`). Don't poll `viewModel.state.value`.
- Assert the **full state sequence** the test cares about — including `Loading` before `Success` — not just the final value.

The scaffold's `FeedViewModelTest` in `.claude/skills/android-app-skeleton/references/tests.md` is the canonical example.

## Analytics-on-init assertion (project rule)

Every `<Feature>ViewModel` in this project injects `AnalyticsTracker` and fires the screen-viewed event from `init { }`. Every VM test asserts the event fires exactly once on construction:

```kotlin
private val analytics: AnalyticsTracker = mockk(relaxed = true)

@Test
fun `fires FeedViewed when constructed`() {
    FeedViewModel(getFeed, analytics)
    verify(exactly = 1) { analytics.track(AnalyticsEvent.FeedViewed) }
}
```

Use `relaxed = true` so unrelated tracker calls don't need `every { ... } returns Unit` plumbing. For specific downstream events (e.g. "tapping retry fires `FeedRetried`"), keep the relaxed mock and add a `verify(exactly = 1) { analytics.track(AnalyticsEvent.FeedRetried) }`.

If you add a VM test that doesn't assert the `init { }` event, the reviewer flags it as missing coverage of the canonical pattern.

## Fakes vs mocks (project heuristic)

**Default to fakes for classes with >2 methods or non-trivial behavior.** Fakes are cheaper to maintain than 20 `coEvery` lines.

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
- Collaborators used for exactly one call in one test.

## Compose UI test conventions

- Drive the **stateless `<Feature>Screen`**, not the `<Feature>Route` — see the Route/Screen split in `compose-ui`. No Hilt setup needed.
- Wrap `setContent { }` in `AppTheme` so theming-dependent assertions work.
- Prefer **semantic matchers** (`onNodeWithText`, `onNodeWithContentDescription`) over `testTag`. Add a `testTag` only when there's no natural semantic.

Canonical example: `FeedScreenTest` / `ProfileScreenTest` in `.claude/skills/android-app-skeleton/references/tests.md`.

## Hilt instrumentation tests — `@BindValue` shortcut

For Hilt-aware tests that need to swap one binding, **don't write a whole test module** — use `@BindValue`:

```kotlin
@HiltAndroidTest
class OrderFlowTest {
    @get:Rule(order = 0) val hiltRule = HiltAndroidRule(this)
    @get:Rule(order = 1) val composeRule = createAndroidComposeRule<MainActivity>()

    @BindValue @JvmField
    val repo: OrderRepository = FakeOrderRepository().apply {
        orders = mapOf(OrderId("x") to ORDER_X)
    }

    @Before fun setUp() { hiltRule.inject() }
}
```

`@BindValue` is the single biggest test-ergonomics win Hilt provides — uses constructor injection on the test class to swap the production binding per-test. See `hilt-di` for the test runner / `HiltTestApplication` setup.

## Don'ts

- No `Thread.sleep` or bare `delay` outside `runTest`.
- No real network in unit tests. Real Room only via `Room.inMemoryDatabaseBuilder` and only when you must.
- No test depending on the order of other tests — each test sets up its own world.
- No `verify` without `exactly = N` when you care about call count (default verify is "at least once").
- No `LiveData` test rules in new code — `InstantTaskExecutorRule` is a smell that LiveData snuck in.
