---
name: navigation-stack
description: Project-specific NavigationStack conventions — typed `Hashable` destinations, one `.navigationDestination` at the stack root, deep links as path mutations, per-tab paths, and the sheet-vs-push rule. Load whenever adding a screen, a navigation transition, or a deep link.
---

# NavigationStack (project delta)

For `NavigationStack` fundamentals — path bindings, `navigationDestination(for:)` mechanics, `NavigationSplitView`, sheet presentation — read [Apple's NavigationStack documentation](https://developer.apple.com/documentation/swiftui/navigationstack). This file documents only this project's decisions.

## When this applies

`NavigationStack` with typed `Hashable` destinations (iOS 16+). On an existing app:

- **`NavigationView`** → deprecated, but migrating is its own change. Don't fold it into an unrelated PR; flag it and move on.
- **UIKit `UINavigationController` / coordinators** → skip this skill. The typed-route principle transfers; the API doesn't.
- **`NavigationLink(destination:)` push-by-view throughout** → the codebase chose view-based navigation. Apply the typed shape to *new* destinations rather than rewriting the existing graph.
- **TCA / a third-party router** (`@Reducer` navigation, `NavigationStackStore`, FlowStacks) → that library owns routing; skip.

## Typed destinations

Routes are an enum conforming to `Hashable` — **never a `String`, never `AnyHashable`**:

```swift
enum Destination: Hashable {
    case orderDetail(id: OrderID)
    case search(initialQuery: String)
    case settings
    case legal(LegalPage)
}
```

**One `.navigationDestination(for:)` per type, installed unconditionally at the root of the stack.** Scattering them per-screen, or putting one inside an `if` branch, makes resolution order unpredictable — SwiftUI only sees destinations registered on the visible path.

```swift
NavigationStack(path: $path) {
    HomeRootView(onOpenOrder: { path.append(.orderDetail(id: $0)) })
        .navigationDestination(for: Destination.self) { destination in
            switch destination {
            case .orderDetail(let id): OrderDetailRootView(id: id, container: container)
            case .search(let q):       SearchRootView(initialQuery: q, container: container)
            case .settings:            SettingsRootView()
            case .legal(let page):     LegalView(page: page)
            }
        }
}
```

**The root composes the graph; screens don't know it.** A feature view receives a closure for what it can navigate to (`onOpenOrder:`), not the path binding. That's what keeps features independent of each other.

The scaffolded `Navigation/Destination.swift` in `${CLAUDE_PLUGIN_ROOT}/skills/ios-app-skeleton/references/app-features.md` is the canonical starting point.

## Path is an array

```swift
path.append(.orderDetail(id: id))   // push
_ = path.popLast()                  // pop
path.removeAll()                    // pop to root
path = [.orderDetail(id: id), .receipt(id: id)]   // multi-step deep link
```

Treat it as ordinary state. There's no navigation API to learn beyond array mutation.

## Deep links

Deep links are path mutations, and the URL→route parsing lives in **its own file** (`Destination+URL.swift`), not in a view:

```swift
.onOpenURL { url in
    guard let destination = Destination(url: url) else { return }
    path.append(destination)
}
```

Keeping `init?(url:)` out of the UI means link rules are unit-testable without a view.

## Sheets vs push

- **Push** for hierarchical drill-in: list → detail → edit.
- **`.sheet(item:)`** for modal flows the user can abandon with a gesture: compose, confirm payment, onboarding.
- A flow inside a sheet gets **its own `NavigationStack` and its own path**. Don't try to share the parent's.
- **One sheet binding per screen**, driven by a state enum describing which sheet is showing. Chained `.sheet` modifiers fight each other.

## Tab-embedded stacks

One `NavigationStack` per tab, each with an independent path. `TabView(selection:)` tracks the active tab; the paths are separate `@State` values and must stay that way — a shared path across tabs loses each tab's history.

## Cross-cutting navigation

When navigation has to be driven from outside the view tree (a widget intent, a push notification, a deep link handled at app level), put the paths in an `@Observable @MainActor` navigator injected from the composition root:

```swift
@Observable @MainActor
final class AppNavigator {
    var homePath: [Destination] = []
    func openOrder(_ id: OrderID) { homePath = [.orderDetail(id: id)] }
}
```

## Testing

There is nothing to test about `NavigationStack` itself. Test that `Destination(url:)` parses correctly, and that the navigator mutates its path as expected. For UI tests, put an `accessibilityIdentifier` on every element that produces a destination.

## Hard nos

- **No `NavigationLink(destination:)`** value-less variants in new code — push-by-view makes the back stack opaque and unaddressable by deep links.
- **No `[AnyHashable]` path** when the routes can be an enum.
- **No `.navigationDestination(for:)` inside a conditional** or on a child screen.
- **No `.sheet` chained inside another `.sheet`** through bindings.
- **No navigation triggered from a `.task { }`** that restarts on state changes — pin it to `.task(id:)`.
