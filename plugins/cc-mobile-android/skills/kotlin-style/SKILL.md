---
name: kotlin-style
description: Kotlin coding conventions and idioms enforced on this project. Load whenever writing or reviewing Kotlin — naming, nullability, data/sealed classes, coroutines, Flow, error handling, and when to use each scope function.
---

# Kotlin style

## Naming

- `PascalCase` for types, `camelCase` for functions, values, and properties.
- `UPPER_SNAKE_CASE` only for `const val` at file / companion level.
- Composables: `PascalCase`, named after the thing they render.
- Use cases: verb-based classnames, `GetUserProfileUseCase`, `SubmitOrderUseCase`.
- Boolean getters: `isX`, `hasY`, `canZ`.

## Nullability

- Prefer non-null types. A nullable return should carry meaning ("absent" vs "error").
- `!!` is a smell. Replace with `requireNotNull(x) { "reason" }`, `checkNotNull`, `?.let`, or `?: error("reason")`.
- Don't use nullable `Boolean` or nullable `Int` casually — use a sealed result type or an explicit default.

## Data classes, sealed classes, value classes

- **Data classes** for value objects. Free `equals`/`hashCode`/`copy`/`toString`.
- **Sealed class / sealed interface** for closed hierarchies: `UiState`, `DomainError`, `Outcome<T>`. Prefer `sealed interface` when there's no shared state.
- **Value classes** (`@JvmInline value class OrderId(val raw: String)`) for type-safety over primitives — IDs, currency codes, percentages.

## Scope functions

| Function | Receiver | Returns | Use for |
|---|---|---|---|
| `let` | `it` | lambda result | null-safety chains, mapping a non-null value |
| `run` | `this` | lambda result | configuring + computing from a receiver |
| `apply` | `this` | the receiver | configuring an object, returns it |
| `also` | `it` | the receiver | side effects (logging, assertion) mid-chain |
| `with` | `this` | lambda result | working with a non-null receiver |

Don't nest them. If you're writing `let { apply { run { ... } } }`, split into functions.

## Coroutines and Flow

- `suspend fun` for one-shot async work.
- `Flow` for streams. `StateFlow` for UI state (always has a current value). `SharedFlow` for event buses. `Channel` for effects you want to consume exactly once.
- Never use `GlobalScope`.
- Use structured concurrency: `viewModelScope`, `applicationScope`, `coroutineScope { }` for parallel-then-join.
- Switch dispatchers at the boundary that does the work:
  ```kotlin
  override suspend fun fetch(): Result<T> = withContext(Dispatchers.IO) { ... }
  ```
- Cancellation is cooperative — check `ensureActive()` in long loops, honour `CancellationException`.
- Test coroutines with `runTest { }` and inject a `TestDispatcher`.

## Error handling

- Business operations return `Result<T>` or a sealed `Outcome`:
  ```kotlin
  sealed interface Outcome<out T> {
      data class Success<T>(val value: T) : Outcome<T>
      data class Failure(val error: DomainError) : Outcome<Nothing>
  }
  ```
- `runCatching { ... }` at layer boundaries is fine. Don't use it as a drop-in `try/catch` anywhere else — it swallows `CancellationException` unless you rethrow.
- Map platform exceptions to domain errors in the repository. The domain layer shouldn't know about `IOException` or `HttpException`.

## Functions

- Default arguments > overload explosions.
- Named arguments at call sites with 3+ parameters.
- Extension functions for operations on types you don't own, or to read like DSL. Don't use them to hide state.
- Top-level functions live in files named for what they do, not `Util.kt`. `StringExtensions.kt`, `FlowExtensions.kt` are fine.

## Immutability

- `val` by default, `var` only when you need reassignment.
- Prefer `List`/`Map`/`Set` (read-only) over `Mutable*`.
- Copy, don't mutate:
  ```kotlin
  state = state.copy(items = state.items + newItem)
  ```

## Visibility

- `internal` is the default for module-internal APIs.
- `private` for file- or class-internal helpers.
- `public` should be deliberate.
