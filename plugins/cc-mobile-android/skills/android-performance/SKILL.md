---
name: android-performance
description: Android performance patterns — Baseline Profiles, Macrobenchmark, Compose recomposition counting, StrictMode, Perfetto traces, startup + scroll measurement. Load when investigating jank, cold-start regressions, or shipping a release build.
---

# Android performance

## Measure first, optimize after

Performance claims without a `Macrobenchmark` run or Perfetto trace are opinions. Every optimization in this repo has a before/after number attached.

## Baseline Profiles

Mandatory for release. A Baseline Profile primes AOT compilation for the user journeys captured during a benchmark run; cold-start improvements in the 20-40% range are typical.

1. Add the `baselineprofile` module with Google's Gradle plugin.
2. Write a `BaselineProfileRule` test that drives your critical flows (launch, first screen, navigation to top 2 features).
3. Run `./gradlew :app:generateReleaseBaselineProfile` — profile lands under `app/src/release/generated/baselineProfiles/`.
4. CI regenerates on demand, not every PR. Manual bump + code review.

Don't hand-edit the generated profile.

## Macrobenchmark

```kotlin
@RunWith(AndroidJUnit4::class)
class StartupBenchmark {
    @get:Rule val rule = MacrobenchmarkRule()

    @Test fun startup() = rule.measureRepeated(
        packageName = "com.example.app",
        metrics = listOf(StartupTimingMetric()),
        iterations = 10,
        startupMode = StartupMode.COLD,
    ) {
        pressHome()
        startActivityAndWait()
    }

    @Test fun scrollFeed() = rule.measureRepeated(
        packageName = "com.example.app",
        metrics = listOf(FrameTimingMetric()),
        iterations = 5,
        startupMode = StartupMode.WARM,
    ) {
        startActivityAndWait()
        device.findObject(By.res("feed")).fling(Direction.DOWN)
    }
}
```

- Always run against a **release** build — debug builds include JIT warmup and `compose-runtime` debug helpers.
- Report `timeToInitialDisplayMs` and `timeToFullDisplayMs` (call `reportFullyDrawn()` from the feature after first meaningful render).

## Compose recomposition

### Counting recompositions in debug

```kotlin
@Composable
fun OrderRow(order: Order) {
    SideEffect { Log.d("Recomp", "OrderRow ${order.id}") } // debug only
}
```

Better: Layout Inspector's recomposition count column (Android Studio Hedgehog+).

### Rules of thumb

- **Stable types**: primitives, `@Immutable`/`@Stable`-annotated data classes, `persistentListOf`/`ImmutableList` from Kotlinx collections-immutable.
- Unstable lambdas: `onClick = { viewModel.onClick(id) }` captures `id` + `viewModel`; if `id` is a stable key, lift the lambda with `remember(id) { { viewModel.onClick(id) } }`.
- `derivedStateOf` for reads derived from `State` that change less often than the source.
- `key(id)` around loop bodies in `LazyColumn` items — not decorative, controls item identity across updates.

### Compose compiler metrics

```kotlin
kotlin {
    compilerOptions {
        freeCompilerArgs.addAll(
            "-P", "plugin:androidx.compose.compiler.plugins.kotlin:reportsDestination=${project.layout.buildDirectory.dir("compose_reports").get().asFile}",
        )
    }
}
```

Look at `module.json` for `restartable` / `skippable` percentages. Unstable classes show up in `classes.txt`.

## StrictMode

Enable in Application `onCreate` on debug only:

```kotlin
if (BuildConfig.DEBUG) {
    StrictMode.setThreadPolicy(StrictMode.ThreadPolicy.Builder()
        .detectDiskReads().detectDiskWrites().detectNetwork()
        .penaltyLog().build())
    StrictMode.setVmPolicy(StrictMode.VmPolicy.Builder()
        .detectLeakedClosableObjects().detectLeakedSqlLiteObjects()
        .penaltyLog().build())
}
```

Crashes you catch in dev save you a 1-star review in prod.

## Perfetto / system traces

Custom trace sections for expensive work:

```kotlin
import androidx.tracing.trace

trace("OrderListLoad") {
    val orders = repository.load()
    // ...
}
```

Record a trace via `adb shell perfetto ...` or Android Studio's profiler, then annotate the captured `trace-...-pftrace` with your sections to find long tasks.

## Startup

- **App Startup** library for eager one-shot initializers (WorkManager, analytics). Don't fork startup into a dozen scattered `ContentProvider`s.
- Hilt's `@InstallIn(SingletonComponent::class)` modules are lazy — safe.
- Ban any synchronous IO from `Application.onCreate`, including Firebase init (use `FirebaseApp.initializeApp(this)` in a background executor if you need custom config).

## Lists

- `LazyColumn` / `LazyRow` over `Column { items.forEach { } }` for >10 items.
- `items(list, key = { it.id })` — without the key, any mutation re-creates every item.
- `contentType = { it::class }` groups compatible items for fewer composition slot resets.
- Paging 3 for >500 items or paginated API.

## Images

- `coil-compose` with `SubcomposeAsyncImage` for placeholders.
- Explicit `size(Dimension.Pixels(w), Dimension.Pixels(h))` on the ImageRequest when the display size is known — avoids re-decoding.
- Disk cache is on by default; don't disable.

## Hard nos

- No optimizing without a measurement.
- No `remember { mutableStateOf(...) }` for values that should come from the ViewModel.
- No work on the main thread in `onCreate` that reads disk or network.
- No `CompositionLocal` abuse for scalar state that changes frequently — every read site recomposes.
- No benchmarking on a debug build and claiming a result.
