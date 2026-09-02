---
name: navigation-compose
description: Project-specific Navigation Compose 2.8+ conventions — typed `@Serializable` destinations, `SavedStateHandle.toRoute<T>()` arg binding in ViewModels, the no-string-routes hard-no, and single-Activity + `enableEdgeToEdge` shape. Load whenever adding a screen, route, or nav graph. For Jetpack Navigation 3, see [`navigation-3`](https://github.com/android/skills/tree/main/navigation/navigation-3) (tracked as a follow-up in the marketplace).
---

# Navigation Compose (project delta)

For Nav Compose fundamentals — destination model, `NavHost`, `composable<T>()`, `entry.toRoute<T>()`, nested graphs, `deepLinks`, result-passing via `SavedStateHandle` — read the [official Navigation Compose guide](https://developer.android.com/develop/ui/compose/navigation). This file documents only this project's conventions.

## When this applies

Navigation Compose **2.8+** with typed `@Serializable` destinations. On an existing app:

- **Navigation 3** (`androidx.navigation3.*`, `NavBackStack`, scene strategies) → use Google's [`navigation-3`](https://github.com/android/skills/tree/main/navigation/navigation-3) skill instead. The patterns here are the prior generation; we're tracking Nav 3 migration as a marketplace follow-up.
- **String-route Nav Compose** (`composable("orders/{orderId}")`) → upgrade only if the user asks; the typed shape requires `kotlinx-serialization` and a coordinated migration.
- **AndroidX Navigation with XML graphs** (`res/navigation/`, `findNavController()`) → skip; that's View-based and out of scope.
- **No navigation library / hand-rolled routing** → don't introduce Nav Compose unless the user asks.

## Single-Activity shape (project mandate)

- **One `Activity`** hosting `AppNavHost`. No multi-Activity navigation.
- **`enableEdgeToEdge()`** in `MainActivity.onCreate()` — see `${CLAUDE_PLUGIN_ROOT}/skills/android-app-skeleton/references/app-module.md`. Screens that need to respect insets do so via `Modifier.safeDrawingPadding()` or `Scaffold` content padding, not by disabling edge-to-edge.
- The top-level graph lives in `core/navigation/AppNavGraph.kt`; feature graphs are composed in via `NavGraphBuilder` extension functions in each feature.

## Destinations — typed only

Destinations are `@Serializable data object` (no args) or `@Serializable data class` (with args). Arg types are limited to what `NavType` supports natively (String/Int/Long/Boolean/Float). **Nullable primitive args require a default value** — Nav Compose can't synthesize a null sentinel otherwise.

The route declaration lives in the feature's `ui/` package (e.g. `feature/orders/ui/OrderDetailRoute.kt`); the top-level `AppNavGraph` imports it. **No string routes in new code** — the reviewer flags `composable("home")`-style calls every time.

## ViewModel arg binding — `SavedStateHandle.toRoute<T>()`

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

**Don't pass args through composable parameters when the ViewModel owns them** — it duplicates the source of truth. The Route composable calls `hiltViewModel()`; the VM reads its own args from `SavedStateHandle.toRoute<T>()`.

Also: **no raw `NavBackStackEntry.arguments?.getString("...")` lookups.** That's the string-route shape sneaking back in.

## Result passing — `previousBackStackEntry.savedStateHandle`

Use `SavedStateHandle` on the **previous** back-stack entry, not an event bus. **Consume-once semantics:** set the result back to `null` after reading, so a config-change-driven recomposition doesn't replay it.

The full code shape is in the official guide; the project rule is "previous entry + consume-once, never `SharedFlow` across screens for nav results."

## Deep links

Declare on the destination via `navDeepLink<DestinationType>(basePath = "...")`. The matching `intent-filter` in the manifest must match the host + scheme. Deep-link URLs are derived from the destination's serial form — keep the `@Serializable` field names stable across releases or rebuild deep-link paths.

## Hard nos

- **No string routes** (`composable("home")`) in new code.
- **No complex objects in nav args.** Pass IDs; let the destination's ViewModel load.
- **No `LaunchedEffect(true)`** that calls `navController.navigate(...)` — the effect re-fires on recomposition and the back stack goes to hell. Key the effect properly.
- **No nav from arbitrary depths** in the composable tree. The Route owns navigation; child composables call up via lambdas.
- **No multi-Activity navigation.** Single-Activity is a project mandate.
- **`launchSingleTop = false`** combined with `popUpTo(...) { inclusive = true }` plus a shared ViewModel re-creates the graph VM unexpectedly — flagged if used without comment.
