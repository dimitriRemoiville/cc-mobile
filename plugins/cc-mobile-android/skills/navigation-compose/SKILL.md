---
name: navigation-compose
description: Navigation Compose 2.8+ type-safe routes via @Serializable destinations, nested graphs, result passing, deep links. Load whenever adding a screen, route, or nav graph.
---

# Navigation Compose (type-safe)

## Why

String routes (`"orders/{orderId}"`) push arg parsing into the body and make nav call sites stringly-typed. Since Nav Compose 2.8 you can model destinations as `@Serializable` classes / objects; the library derives the route and arg parsing for you.

## Destination model

One file per nav graph. Destinations are `@Serializable` `data object` (no args) or `data class` (with args).

```kotlin
@Serializable data object Home
@Serializable data object Cart
@Serializable data class OrderDetail(val orderId: String)
@Serializable data class Search(val initialQuery: String = "")
```

- Arg types are limited to what `NavType` supports natively (String/Int/Long/Boolean/Float) plus `@Serializable` parcelable-equivalents. Custom types need a `NavType` declaration.
- **No nullable primitive args unless you also default them.** Nav Compose can't synthesize a null sentinel without a default.

## Graph

```kotlin
@Composable
fun AppNavHost(navController: NavHostController = rememberNavController()) {
    NavHost(navController = navController, startDestination = Home) {
        composable<Home> { HomeRoute(onOpenOrder = { id -> navController.navigate(OrderDetail(id)) }) }
        composable<Cart> { CartRoute() }
        composable<OrderDetail> { entry ->
            val route: OrderDetail = entry.toRoute()
            OrderDetailRoute(orderId = route.orderId)
        }
        composable<Search> { entry ->
            SearchRoute(initialQuery = entry.toRoute<Search>().initialQuery)
        }
    }
}
```

`entry.toRoute<T>()` deserialises the route into the typed destination. Don't go back to pulling args out of `SavedStateHandle` by string key.

## ViewModel destination binding

ViewModels pick up destination args through `SavedStateHandle.toRoute<T>()`:

```kotlin
@HiltViewModel
class OrderDetailViewModel @Inject constructor(
    handle: SavedStateHandle,
    private val getOrder: GetOrderUseCase,
) : ViewModel() {
    private val route: OrderDetail = handle.toRoute()
    init { load(route.orderId) }
}
```

Don't pass args through composable parameters when the ViewModel owns them — it duplicates the source of truth.

## Nested graphs

For feature modules, a graph extension function keeps routes local:

```kotlin
fun NavGraphBuilder.ordersGraph(onOpenDetail: (String) -> Unit) {
    navigation<OrdersGraph>(startDestination = OrdersList) {
        composable<OrdersList> { OrdersListRoute(onOpenDetail = onOpenDetail) }
        composable<OrderDetail> { /* ... */ }
    }
}

@Serializable data object OrdersGraph
@Serializable data object OrdersList
```

## Result passing

Use `SavedStateHandle` on the **previous** back stack entry, **not** an event bus:

```kotlin
// On the detail screen, return a result to the caller
navController.previousBackStackEntry
    ?.savedStateHandle
    ?.set("order_result", OrderResult.Placed(id = orderId))
navController.popBackStack()

// On the caller screen, observe it
val result = navController.currentBackStackEntry
    ?.savedStateHandle
    ?.getStateFlow<OrderResult?>("order_result", null)
    ?.collectAsStateWithLifecycle()
```

Consume-once semantics: set back to `null` after reading.

## Deep links

Declare with `deepLinks`:

```kotlin
composable<OrderDetail>(
    deepLinks = listOf(navDeepLink<OrderDetail>(basePath = "https://example.com/orders")),
) { /* ... */ }
```

Add the matching `intent-filter` in the manifest. Deep-link URLs are derived from the serial form of the destination.

## Top-level single-activity

- One `Activity` hosting `AppNavHost`.
- Use `enableEdgeToEdge()` in the Activity + `Modifier.safeDrawingPadding()` at the root composable of each screen.
- Animations via `composable<T>(enterTransition = { ... }, exitTransition = { ... })`.

## Hard nos

- No string routes (`composable("home")`) in new code.
- No passing complex objects through nav args — pass ids, let the ViewModel load.
- No `launchSingleTop = false` with `popUpTo(...) { inclusive = true }` combined with a shared ViewModel — it re-creates the graph VM unexpectedly.
- No raw `NavBackStackEntry.arguments?.getString("...")` lookups. Use `entry.toRoute<T>()`.
- No nav from within an effect that can restart (`LaunchedEffect(true)` without a keyed scope) — navigation fires on recomposition and the back stack goes to hell.
