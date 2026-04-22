---
name: navigation-stack
description: NavigationStack patterns for this iOS project — typed destinations via Hashable enums, path binding, deep links, sheet/presentation coordination, programmatic pop, tab-embedded stacks. Load whenever adding a screen or navigation transition.
---

# NavigationStack

## Why not NavigationView

`NavigationView` is deprecated for stacks. `NavigationStack` gives:
- Typed destinations via `.navigationDestination(for:)`.
- A writable `path` binding for programmatic navigation + deep links.
- Proper back stack state (no silent invalidation on iOS 16+).

## Typed destinations

Model routes as an enum conforming to `Hashable`:

```swift
enum AppRoute: Hashable {
    case orderDetail(id: String)
    case search(initialQuery: String)
    case settings
    case legal(LegalPage)
}

enum LegalPage: Hashable { case privacy, terms }
```

Bind with `.navigationDestination(for:)`:

```swift
struct AppRootView: View {
    @State private var path: [AppRoute] = []
    @Environment(\.diContainer) private var container

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(onOpenOrder: { id in path.append(.orderDetail(id: id)) })
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .orderDetail(let id): OrderDetailView(viewModel: container.orderDetailViewModel(id: id))
                    case .search(let q):       SearchView(viewModel: container.searchViewModel(initial: q))
                    case .settings:            SettingsView()
                    case .legal(let page):     LegalView(page: page)
                    }
                }
        }
    }
}
```

One `.navigationDestination(for:)` per type, installed at the root of the stack. Don't scatter them per view — the resolution order becomes unpredictable.

## Push / pop

```swift
path.append(.orderDetail(id: "abc"))    // push
_ = path.popLast()                       // pop
path.removeAll()                         // pop to root
```

Path is just a mutable array. Treat it as one.

## Sheets vs push

- Use push for hierarchical drill-in (list -> detail -> edit).
- Use `.sheet(item:)` for modal flows (compose email, confirm payment) that can be dismissed with a gesture.
- Nested flows inside a sheet get their own `NavigationStack`, with their own path. Don't try to share.

```swift
@State private var composing: ComposeDraft?

// in body:
.sheet(item: $composing) { draft in
    NavigationStack { ComposeView(draft: draft) }
}
```

## Deep links

Deep links become path append operations:

```swift
.onOpenURL { url in
    guard let route = AppRoute(url: url) else { return }
    path.append(route)
}
```

For multi-step deep links, push multiple entries:

```swift
case "order-receipt":
    let id = url.pathComponents[2]
    path = [.orderDetail(id: id), .receipt(id: id)]
```

`AppRoute.init(url:)` lives in its own file so linking rules don't bleed into the UI.

## Tab-embedded stacks

One `NavigationStack` per tab, each with its own path. Use `TabView(selection:)` to track the active tab; the paths are independent state.

```swift
struct RootTabs: View {
    @State private var selection: Tab = .home
    @State private var homePath: [AppRoute] = []
    @State private var cartPath: [AppRoute] = []

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $homePath) { HomeRoot() }.tabItem { /* ... */ }.tag(Tab.home)
            NavigationStack(path: $cartPath) { CartRoot() }.tabItem { /* ... */ }.tag(Tab.cart)
        }
    }
}
```

## Observable navigation (iOS 18+)

For cross-cutting navigation state (e.g., handle an intent from a widget), store the path in an `@Observable` coordinator:

```swift
@Observable @MainActor final class AppNavigator {
    var homePath: [AppRoute] = []
    func openOrder(_ id: String) { homePath = [.orderDetail(id: id)] }
}
```

Inject and call from the URL handler or a `UNUserNotificationCenterDelegate`.

## Testing

For UI tests, `accessibilityIdentifier` on each destination-producing element. For view-model testing, there's nothing to test about `NavigationStack` itself — test that the coordinator mutates its path.

## Hard nos

- No `NavigationLink(destination:)` value-less variants in new code (push-by-view makes the back stack opaque).
- No path of `AnyHashable` when you can model routes with an enum.
- No `.sheet` inside `.sheet` chained through bindings — use one sheet with a state enum describing which sheet is showing.
- No triggering navigation from inside a `.task { ... }` that restarts on state changes; pin it to `.task(id:)`.
- No putting `.navigationDestination(for:)` inside `if` branches; install unconditionally at the root.
