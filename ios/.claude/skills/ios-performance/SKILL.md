---
name: ios-performance
description: iOS performance patterns — Instruments tracing, SwiftUI `Self._printChanges()`, MetricKit, launch optimization, scroll smoothness, memory pressure, Signposts. Load when investigating jank, cold-start regressions, or shipping a release build.
---

# iOS performance

## Measure first

Any performance claim needs an Instruments trace, a MetricKit report, or a Signpost-annotated profile. No opinions in PR descriptions.

## Launch time

- `AppLauncher` + `didFinishLaunchingWithOptions` executes on the main thread. Every synchronous thing here delays the first frame.
- Move Firebase init, analytics setup, log-shipping to a `Task.detached(priority: .utility) { ... }` or wait for first scene if possible.
- Use the **Time Profiler** and **App Launch** templates in Instruments.
- Measure `TTFF` (time to first frame) and `TTI` (time to interactive). The latter is the metric that actually matters.

Pre-main contributions (dylib loading, objc init) show up in the App Launch template under "dylib loading" — cutting heavy Swift Package deps from the main target trims this.

## SwiftUI recomposition

### Print changes (iOS 17+)

```swift
struct OrderRow: View {
    let order: Order

    var body: some View {
        let _ = Self._printChanges()
        // ...
    }
}
```

Log goes to the console when the body re-evaluates. Quietly remove before shipping.

### Reduce body re-evaluation

- Hold as little state as possible in a view. Pass sliced view models, not the whole store.
- `@Observable` macro automatically tracks per-property access — a view that reads `vm.title` only invalidates on `title` changes.
- For derived values, compute in the view model, not in body.
- `LazyVStack` / `List` for >50 rows; never `ForEach` inside a `ScrollView` for large sets.

```swift
List(orders) { order in OrderRow(order: order) }
    .listStyle(.plain)
```

Identifiable conformance is required. Use a stable `id`, not `\.self` on a value with equality quirks.

## Scroll smoothness

- Every cell's `body` should be cheap. Expensive work -> pre-computed in view model.
- Use `AsyncImage` with a `contentMode:` and explicit size. Prefer `.task {}` + a typed image pipeline if you need caching / transformations.
- Avoid `GeometryReader` in cells — it invalidates on every frame and tanks scroll.
- `.drawingGroup()` for complex paths/effects that otherwise recompose every frame.

## Memory

- Images: `UIImage(contentsOfFile:)` loads lazily; `UIImage(named:)` keeps in the named cache. Explicitly release or reuse.
- `Data` arrays over 1MB should go through streams.
- Use Xcode's **Allocations** instrument to catch retain cycles. Combine publishers held on `self` without a `.sink(...)` stored in `cancellables` leak quietly.
- `weak` captures in closures crossing async boundaries: prefer structured tasks (`.task { ... }`) so the lifecycle is tied to the view.

## Signposts (custom instrument ranges)

```swift
import OSLog

private let logger = Logger(subsystem: "com.example.app", category: "orders")
private let signposter = OSSignposter(subsystem: "com.example.app", category: "orders")

func loadOrders() async throws {
    let state = signposter.beginInterval("load-orders")
    defer { signposter.endInterval("load-orders", state) }
    // work...
}
```

Show up in Instruments' **Points of Interest** lane. Use short, stable names — they become column headers.

## MetricKit

For production insights:

```swift
final class MetricSubscriber: NSObject, MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) { /* upload */ }
    func didReceive(_ payloads: [MXDiagnosticPayload]) { /* upload */ }
}
// In App init:
MXMetricManager.shared.add(MetricSubscriber())
```

Payloads arrive daily per device with launch times, hang rates, CPU/energy breakdowns. Ship to your analytics pipe.

## Main thread hygiene

- Don't hold locks across `await`.
- Don't call `URLSession.shared.data(for:)` on the main actor if you can push it to an actor repo.
- Never call `DispatchSemaphore.wait()` from the main thread.

## Instruments checklist for a regression

1. **Time Profiler** — who's eating CPU.
2. **Allocations** — any runaway growth, any unexpectedly large heap at steady state.
3. **Leaks** — retain cycles.
4. **Hangs** — where the main thread blocked for >250ms.
5. **SwiftUI** — body counts, rendering frame hitches.

Record on a release build. Debug builds include non-optimized Swift and dylib validation overhead.

## Hard nos

- No optimization without a before/after measurement.
- No `@State` for values that live outside the view.
- No `onAppear { Task { ... } }` where `.task { ... }` is the right tool.
- No heavy logging in release (`print(...)` included).
- No profiling in debug and claiming a result.
