---
name: compose-ui
description: Authoritative playbook for building Jetpack Compose screens and components in this project. Use whenever writing or editing any `@Composable`, setting up navigation destinations, themeing, previews, or state collection. Covers Material 3, state hoisting, recomposition discipline, accessibility, and testing hooks.
---

# Compose UI skill

This skill governs every Compose change in the project.

## The shape of a screen

A screen is split into two functions: a stateful **Route** that owns the ViewModel, and a stateless **Screen** that renders state and surfaces callbacks.

```kotlin
@Composable
fun OrderRoute(
    onBack: () -> Unit,
    onCheckout: (OrderId) -> Unit,
    viewModel: OrderViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                is OrderEvent.Checkout -> onCheckout(event.id)
            }
        }
    }

    OrderScreen(
        state = state,
        onBack = onBack,
        onAction = viewModel::onAction,
    )
}

@Composable
fun OrderScreen(
    state: OrderUiState,
    onBack: () -> Unit,
    onAction: (OrderAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier,
        topBar = { OrderTopBar(onBack = onBack) },
    ) { padding ->
        when (state) {
            OrderUiState.Loading -> LoadingContent(Modifier.padding(padding))
            is OrderUiState.Error -> ErrorContent(state.message, Modifier.padding(padding))
            is OrderUiState.Success -> OrderContent(
                order = state.order,
                onAction = onAction,
                modifier = Modifier.padding(padding),
            )
        }
    }
}
```

## UiState

Always a sealed interface (or sealed class) with explicit branches:

```kotlin
sealed interface OrderUiState {
    data object Loading : OrderUiState
    data class Error(val message: String) : OrderUiState
    data class Success(val order: Order) : OrderUiState
}
```

One-off effects (navigation, snackbars, toasts) are NOT state — they are events:

```kotlin
sealed interface OrderEvent {
    data class Checkout(val id: OrderId) : OrderEvent
    data class ShowError(val message: String) : OrderEvent
}
```

## Modifier rules

- First optional parameter, always defaulted: `modifier: Modifier = Modifier`.
- Pass-through to the root layout: `Column(modifier = modifier) { ... }`.
- Composables internally use **new** `Modifier` instances; don't propagate the caller's `modifier` to children unless that's the intent.
- Avoid `Modifier.fillMaxSize()` inside a reusable component — let the caller decide.

## State hoisting

Stateful primitives stay with the ViewModel. Within a Composable, `remember` is acceptable for pure UI state (sheet open/closed, text field value if the ViewModel doesn't care). If the ViewModel ever needs to read or restore it, it belongs in UiState.

## Lists

```kotlin
LazyColumn {
    items(items = products, key = { it.id }) { product ->
        ProductRow(product = product, onClick = { onAction(Click(product.id)) })
    }
}
```

- **Always** provide `key =` for stable identity.
- Hoist the click lambda or use `remember(product.id) { { onAction(Click(product.id)) } }` if you're profiling recompositions.

## Previews

Every non-trivial composable has at least one preview. Previews are **always** wrapped in the app theme:

```kotlin
@Preview(name = "Light")
@Preview(name = "Dark", uiMode = UI_MODE_NIGHT_YES)
@Composable
private fun OrderScreenPreview() = AppTheme {
    OrderScreen(
        state = OrderUiState.Success(fakeOrder()),
        onBack = {},
        onAction = {},
    )
}
```

For multi-state previews, use `PreviewParameterProvider`.

## Theming

- Colors: `MaterialTheme.colorScheme.primary` — never hex literals outside theme files.
- Typography: `MaterialTheme.typography.bodyLarge`. Typography tokens are defined in `Type.kt`.
- Shapes: `MaterialTheme.shapes.medium`.

## Accessibility

- Every `Icon` without adjacent text gets a `contentDescription`.
- Decorative icons: `contentDescription = null` is explicit — don't omit the param.
- Interactive elements must be ≥ 48dp tap target. `Modifier.minimumInteractiveComponentSize()` helps.
- Support dynamic text scaling — don't set `fontSize` with fixed `sp` numbers outside the type scale.

## Recomposition hygiene

- Read state as late as possible. Pushing a state read into the deepest composable that needs it reduces recomposition scope.
- Use `derivedStateOf { }` when a value is derived from multiple state reads and consumed by a hot path.
- Mark stable data classes `@Immutable` when the compiler can't infer stability (e.g., contains a `List<Foo>`).

## Hard nos

- No `LiveData` in new code.
- No `collectAsState()` for ViewModel state — use `collectAsStateWithLifecycle()`.
- No network or DB calls inside a Composable or `LaunchedEffect` that reaches around the ViewModel.
- No `@Composable` longer than ~60-80 lines. Extract children when concerns mix (layout + stateful behaviour + event handling in one function) or nesting exceeds 3 levels. Lines alone aren't the rule; readability is.
