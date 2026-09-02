# Reference — `core/domain/` package

Pure-Kotlin business logic. No `android.*` imports — keep these packages framework-free by convention so they stay unit-testable without Robolectric, and so extracting them to a `:core:domain` module later is mechanical. Loaded at execution-order step 5.

## `app/src/main/java/{{PACKAGE_PATH}}/core/domain/Outcome.kt`

```kotlin
package {{PACKAGE_ID}}.core.domain

sealed interface Outcome<out T> {
    data class Success<T>(val value: T) : Outcome<T>
    data class Failure(val error: DomainError) : Outcome<Nothing>
}

inline fun <T, R> Outcome<T>.map(block: (T) -> R): Outcome<R> = when (this) {
    is Outcome.Success -> Outcome.Success(block(value))
    is Outcome.Failure -> this
}
```

## `app/src/main/java/{{PACKAGE_PATH}}/core/domain/DomainError.kt`

```kotlin
package {{PACKAGE_ID}}.core.domain

sealed class DomainError(open val cause: Throwable? = null) {
    data class Network(override val cause: Throwable? = null) : DomainError(cause)
    data class Unauthorized(override val cause: Throwable? = null) : DomainError(cause)
    data class NotFound(override val cause: Throwable? = null) : DomainError(cause)
    data class Server(val code: Int, override val cause: Throwable? = null) : DomainError(cause)
    data class Unknown(override val cause: Throwable? = null) : DomainError(cause)
}
```

## `app/src/test/java/{{PACKAGE_PATH}}/core/domain/OutcomeMapTest.kt`

A 10-line test anchors the convention: `core/domain/` is plain Kotlin, framework-free, fast to test. Every new use case should have a sibling under `app/src/test/java/{{PACKAGE_PATH}}/<feature>/domain/`.

```kotlin
package {{PACKAGE_ID}}.core.domain

import org.junit.Assert.assertEquals
import org.junit.Test

class OutcomeMapTest {
    @Test
    fun `map transforms Success values`() {
        val result = Outcome.Success(2).map { it * 3 }
        assertEquals(Outcome.Success(6), result)
    }

    @Test
    fun `map propagates Failure unchanged`() {
        val original: Outcome<Int> = Outcome.Failure(DomainError.Network())
        assertEquals(original, original.map { it * 3 })
    }
}
```

## Analytics: `core/domain/analytics/`

The analytics interface is part of the **core/domain** layer so ViewModels and use cases depend on the abstraction, not on Firebase. The `core/data/` layer chooses the concrete implementation (Firebase or no-op) at wire-up time. This is the same pattern as repositories: the contract lives in `core/domain/`, the framework-bound code stays in `core/data/`. Without this split a `FeedViewModel` would import `com.google.firebase.*`, which leaks framework concerns into the layer that's supposed to be framework-free.

The event taxonomy is a sealed type, not a string. Magic strings sprinkled across screens are how analytics dashboards quietly drift; a sealed type forces every new event to land in one place that's grep-able and reviewable.

### `app/src/main/java/{{PACKAGE_PATH}}/core/domain/analytics/AnalyticsTracker.kt`

```kotlin
package {{PACKAGE_ID}}.core.domain.analytics

interface AnalyticsTracker {
    fun track(event: AnalyticsEvent)
    fun setUserProperty(key: String, value: String?)
    /** Toggle collection at runtime (debug builds default off — see Application). */
    fun setCollectionEnabled(enabled: Boolean)
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/core/domain/analytics/AnalyticsEvent.kt`

```kotlin
package {{PACKAGE_ID}}.core.domain.analytics

/**
 * Add events here. The sealed type is the source of truth — implementations
 * route `name` + `params` to whatever backend is wired up (Firebase, Mixpanel, no-op).
 *
 * Keep names snake_case (Firebase + most backends prefer it) and parameters
 * primitive-only (String, Int, Long, Double, Boolean) — that's the intersection
 * of what every backend can serialize without a custom mapper.
 */
sealed class AnalyticsEvent(
    val name: String,
    val params: Map<String, Any?> = emptyMap(),
) {
    data object HomeViewed : AnalyticsEvent(name = "home_viewed")
    data object FeedViewed : AnalyticsEvent(name = "feed_viewed")
    data object ProfileViewed : AnalyticsEvent(name = "profile_viewed")

    data class ItemTapped(val itemId: String) : AnalyticsEvent(
        name = "item_tapped",
        params = mapOf("item_id" to itemId),
    )

    data class ScreenOpenedFromDeepLink(val route: String) : AnalyticsEvent(
        name = "deep_link_open",
        params = mapOf("route" to route),
    )
}
```
