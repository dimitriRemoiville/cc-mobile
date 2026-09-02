---
name: ios-performance
description: iOS performance discipline for this project — measure-before-optimize, launch-time budget, SwiftUI body-invalidation debugging, scroll smoothness, Signposts and MetricKit wiring, and the Instruments pass for a regression. Load when investigating jank, cold-start regressions, hangs, or memory growth.
---

# iOS performance

## When this applies

Largely stack-agnostic. Instruments, Signposts, MetricKit, and the launch-time rules work for any iOS app regardless of architecture. The SwiftUI subsections (body invalidation, `Self._printChanges()`, `@Observable` tracking) apply only where SwiftUI is in use — for UIKit screens, apply the same measurement discipline with the View-system tools (`CADisplayLink` frame timing, `Hangs` and `Time Profiler` instruments).

## Measure first

**A performance claim without a trace is an opinion.** Every optimization in this repo carries a before/after number from Instruments, a MetricKit payload, or a Signpost interval.

Record on a **release build**. Debug builds carry unoptimized Swift, dylib validation, and no cross-module optimization — a Debug profile tells you almost nothing about what ships.

## Launch time

Everything synchronous in app init and `didFinishLaunching` delays the first frame.

- Move analytics, logging, Firebase, and remote-config initialisation off the critical path — after the first scene, or into a low-priority task.
- Measure **TTI** (time to interactive), not just TTFF (time to first frame). TTFF hides a spinner-only first screen.
- Pre-main cost (dylib loading, ObjC `+load`) shows in the **App Launch** template. It is dominated by dynamically linked dependencies: prefer static linking for SPM packages in the main target, and cut dependencies the app doesn't use at launch.

## SwiftUI body invalidation

`@Observable` tracks per-property access, so a view that reads `model.title` re-evaluates only when `title` changes. That's the mechanism most "SwiftUI is slow" reports are actually missing.

When a body evaluates more than expected:

```swift
var body: some View {
    let _ = Self._printChanges()   // remove before shipping
    // ...
}
```

Then fix the cause, in this order:

1. **The view holds too much.** Pass the slice a subview needs, not the whole model.
2. **Derived values computed in `body`.** Compute them in the view model.
3. **A closure or non-`Equatable` value recreated per render**, defeating structural identity.

## Scroll smoothness

- **`List` or `LazyVStack` past ~50 rows.** `ForEach` inside a plain `ScrollView` builds every row.
- **A cell's `body` must be cheap.** Formatting, date math, and string building belong in the view model, precomputed.
- **No `GeometryReader` inside a cell.** It invalidates per frame and reliably tanks scroll.
- Stable identity matters: a real `id`, never `\.self` on a value whose equality is expensive or surprising.
- `.drawingGroup()` for complex paths and effects that otherwise re-render every frame — measure, it isn't free.

## Memory

- Images dominate. `UIImage(named:)` populates a system cache that isn't yours to evict; `UIImage(contentsOfFile:)` doesn't. Downsample before display — a 4000px image in a 200pt view costs the full decoded bitmap.
- Data over ~1MB goes through a stream, not a `Data` in memory.
- **Allocations** for steady-state growth, **Leaks** for cycles. A Combine subscription stored on `self` without a matching teardown leaks quietly and never shows as a crash.
- Prefer `.task { }` over a stored `Task` so lifetime is tied to the view rather than to a `[weak self]` dance.

## Signposts

Custom intervals show up in Instruments' **Points of Interest** lane and are the cheapest way to time your own code in a real trace:

```swift
private let signposter = OSSignposter(subsystem: "com.example.app", category: "orders")

func loadOrders() async {
    let state = signposter.beginInterval("load-orders")
    defer { signposter.endInterval("load-orders", state) }
    // work...
}
```

Names become column headers — keep them short and stable across builds so traces stay comparable.

## MetricKit

Production telemetry: launch times, hang rate, CPU and energy, plus diagnostic payloads for crashes and hangs, delivered daily per device.

```swift
MXMetricManager.shared.add(subscriber)
```

This is the only source of truth for how the app behaves on the devices people actually own. Ship the payloads to your analytics pipeline; a subscriber that logs and discards is wasted wiring.

## The regression pass

In order, on a release build:

1. **Hangs** — where did the main thread block for >250ms.
2. **Time Profiler** — what's eating CPU.
3. **Allocations** — unexpected growth or a large steady-state heap.
4. **Leaks** — retain cycles.
5. **SwiftUI** — body counts and rendering hitches.

## Hard nos

- **No optimization without a before/after measurement.**
- **No profiling a Debug build** and reporting the number.
- **No `@State` for values that outlive the view.**
- **No `onAppear { Task { } }`** where `.task { }` is the right tool — it leaks the task past view lifetime.
- **No heavy logging in release**, `print()` included.
