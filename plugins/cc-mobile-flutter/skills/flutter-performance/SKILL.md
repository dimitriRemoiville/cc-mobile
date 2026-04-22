---
name: flutter-performance
description: Flutter performance patterns — DevTools (Performance, CPU profiler, Memory), rebuild tracking, `const` hygiene, image decoding, `ListView.builder`, `RepaintBoundary`, `--profile` measurement, Skia vs Impeller considerations. Load when investigating jank, scroll stutter, cold-start regressions, or shipping a release build.
---

# Flutter performance

## Measure first

Run in `--profile` mode. Debug builds are slower than release; release builds hide the observatory. `--profile` gives both.

```bash
flutter run --profile --dart-define=flavor=prod
```

Open DevTools, go to **Performance** tab, record a session of the suspect interaction.

## DevTools staples

- **Performance**: UI + raster thread frame times. Any UI-thread frame >16ms on 60Hz or >8ms on 120Hz is a dropped frame.
- **CPU Profiler**: flame graph of what the UI thread is doing during jank.
- **Memory**: track leaks, watch the heap grow.
- **Widget Inspector** + "Highlight Rebuilds" + "Show Performance Overlay" toggles.

## Rebuild tracking

Enable "Track Widget Builds" in the inspector to see which widgets are rebuilding. Aim for: only widgets whose inputs changed rebuild.

For manual logging in dev:

```dart
class OrderRow extends StatelessWidget {
  const OrderRow({super.key, required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    assert(() {
      debugPrint('OrderRow ${order.id} built');
      return true;
    }());
    return /* ... */;
  }
}
```

Ship neither the debug print nor any dev logging — guard behind `assert(() { ...; return true; }());`.

## `const` hygiene

- Constructor with `const`: the widget is canonicalized and skips rebuilds when the context says nothing changed.
- `const` everywhere: `const Icon(...)`, `const SizedBox(...)`, `const EdgeInsets.all(...)`.
- The analyzer flags `prefer_const_constructors` and `prefer_const_literals_to_create_immutables` — keep them on. CI should fail on new violations.

## Bloc / state hygiene

- `BlocSelector` narrows which state changes trigger a rebuild — one per small leaf widget.
- `BlocBuilder` with a custom `buildWhen:` also works.
- Never call `setState` in a `build` method (obviously) and never mutate state inside `builder:`.

## ListView / scroll

- `ListView.builder` (lazy) for >10 items, not `ListView(children: [...])`.
- `itemExtent` or `prototypeItem` — lets the viewport pre-calculate scroll offsets. Makes `jumpTo` + scrollbars accurate, and avoids laying out every item for measurement.
- `CustomScrollView` + `SliverList` when you mix scroll behaviors.

```dart
ListView.builder(
  itemCount: orders.length,
  itemExtent: 72,
  itemBuilder: (context, index) => OrderRow(order: orders[index]),
)
```

## RepaintBoundary

For widgets that animate independently of their siblings (a `ColorFiltered` spinner above a static list), wrap in `RepaintBoundary` so Flutter doesn't invalidate the static siblings' raster caches every frame.

Be selective. `RepaintBoundary` everywhere is itself a cost.

## Images

- Always specify `width`/`height` (or use `cacheWidth`/`cacheHeight`) so Flutter decodes at display size rather than native resolution.
- `Image.asset(...)` with `cacheWidth: 128` for a 64x64 displayed image (2x for hiDPI).
- For network images, `cached_network_image` gives disk + memory caching out of the box.
- `FadeInImage` vs `Image.network`: `FadeInImage` handles placeholder + fade, but it lays out twice — prefer a proper placeholder widget.

## Animations

- `AnimatedBuilder` / `AnimatedWidget` instead of rebuilding the whole subtree every frame.
- Use `RepaintBoundary` around animated subtrees.
- For list reorder animations, `AnimatedList` + key discipline.

## Startup

- `main()` should do: `WidgetsFlutterBinding.ensureInitialized()` → flavor config → `runApp(...)`. Everything else deferred or async.
- Firebase init + remote config: `unawaited(_initializeFirebase())` after `runApp` if you can tolerate a short delay.
- Lazy-load GetIt singletons: prefer `registerLazySingleton` over `registerSingleton` for expensive objects.

## Memory

- Dispose controllers (`TextEditingController`, `ScrollController`, `AnimationController`) in `dispose()`.
- Cancel stream subscriptions.
- `flutter_bloc` handles its own disposal via `close()`; outside bloc, own your subscriptions.

## Platform channels

- Marshalling large payloads over platform channels is expensive. Send ids + fetch details through a dedicated background isolate when the payload is >1MB.
- `pigeon` for typed channels — compile-time safety is cheaper than runtime debugging.

## Isolates

CPU-bound work (image manipulation, parsing large JSON, cryptography) runs off the UI isolate:

```dart
final result = await Isolate.run(() => _parseLargePayload(data));
```

For repeated work, a long-lived isolate pool beats spawning one per call.

## Impeller (iOS and Android)

Impeller is now the default on iOS 17+ and Android 14+. If you see shader compilation jank on first run of a screen, enable **Impeller** explicitly in `Info.plist` (iOS) and `AndroidManifest.xml` (Android). For older devices, Skia's first-run shader warmup via `flutter run --cache-sksl` still applies.

## Shipping measurement

- Run on a low-end device (iPhone SE / Pixel 6a). Not the tester's iPhone 15 Pro.
- Record the P95 frame time over a scripted interaction. PR descriptions include before/after numbers.

## Hard nos

- No optimization without a measurement.
- No `setState` ballooning into business state (use a bloc / cubit / provider).
- No `Image.network('...')` inline for thumbnails — use `cached_network_image` + sized decoding.
- No `StreamBuilder` over a long-lived stream without managing subscription disposal.
- No profiling in debug and claiming a result.
