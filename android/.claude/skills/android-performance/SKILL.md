---
name: android-performance
description: Project-specific Android performance conventions on top of Baseline Profiles, Macrobenchmark, Compose compiler metrics, StrictMode, and Perfetto. Covers the measure-first mandate, the Compose-metrics Gradle wiring, the debug-only StrictMode block, and project-specific hard-nos. Load when investigating jank, cold-start regressions, or shipping a release build.
---

# Android performance (project delta)

For Baseline Profile, Macrobenchmark, Perfetto, and Compose stability fundamentals — read [`developer.android.com/topic/performance`](https://developer.android.com/topic/performance) and Google's Perfetto deep-dive skills: [`profilers/perfetto-trace-analysis`](https://github.com/android/skills/tree/main/profilers/perfetto-trace-analysis) (investigate jank/memory/latency from a captured trace) and [`profilers/perfetto-sql`](https://github.com/android/skills/tree/main/profilers/perfetto-sql) (translate intents into trace_processor SQL). For R8 / Proguard rule audits, see [`performance/r8-analyzer`](https://github.com/android/skills/tree/main/performance/r8-analyzer).

This file documents only this project's conventions on top of those.

## When this applies

Stack-agnostic. The Compose-specific subsections apply only when Compose is in use; for View-based apps, apply the same measurement discipline with View-system tools (Systrace + `Choreographer` frame callbacks).

## Measure first, optimize after (project rule)

**Performance claims without a `Macrobenchmark` run or Perfetto trace are opinions.** Every optimization in this repo ships with a before/after number attached. The reviewer rejects PRs that claim a perf win with no measurement.

## Baseline Profiles

Mandatory for release builds. The `BaselineProfileRule` test drives the critical flows (launch, first screen, top two navigation targets); `./gradlew :app:generateReleaseBaselineProfile` writes the profile under `app/src/release/generated/baselineProfiles/`.

Project rules:
- CI regenerates **on demand**, not every PR. Manual bump + code review.
- Don't hand-edit the generated profile.
- Regeneration policy + the Gradle command sequence live in `android-release` — load that skill at release time.

## Macrobenchmark

- Always run against a **release** build — debug includes JIT warmup and `compose-runtime` debug helpers; results are meaningless.
- Use `StartupTimingMetric` for cold/warm start; `FrameTimingMetric` for scroll/animation.
- **Call `reportFullyDrawn()`** from the feature once the first meaningful render is on screen. Without it, `timeToFullDisplayMs` is whatever Android guesses (usually wrong).
- Iterations: ≥ 10 for cold start, ≥ 5 for warm/scroll. Lower counts produce noisy medians.

## Compose recomposition

For stability rules (stable types, unstable lambdas, `derivedStateOf`, `key()` in `LazyColumn`), use Layout Inspector's recomposition count column (Android Studio Hedgehog+) and the official [Compose performance guide](https://developer.android.com/develop/ui/compose/performance). The project rule on top of that is the **Compose compiler metrics report**, wired in `app/build.gradle.kts`:

```kotlin
kotlin {
    compilerOptions {
        freeCompilerArgs.addAll(
            "-P", "plugin:androidx.compose.compiler.plugins.kotlin:reportsDestination=" +
                "${project.layout.buildDirectory.dir("compose_reports").get().asFile}",
        )
    }
}
```

After a build, `module.json` shows per-`@Composable` `restartable` / `skippable` percentages; `classes.txt` lists unstable classes. PRs that drop the skippable percentage below the previous baseline get flagged.

## StrictMode (debug-only Application block)

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

Lives in `{{APP_CLASS}}.onCreate()`. Never enable in release — the policy callbacks themselves cost frames. The point is to crash loudly in dev so violations don't make it to prod.

## Custom trace sections

Wrap expensive work in `androidx.tracing.trace("Name") { }` to surface it in Perfetto. Use sparingly; `trace { }` itself has a small but non-zero cost per call. Don't wrap hot loops — wrap **boundary calls** (`OrderListLoad`, `FeedSync`, `ImageDecode`).

## Hard nos

- **No optimizing without a measurement.** Reviewer rejects "this should be faster" with no number.
- **No `remember { mutableStateOf(...) }` for values that should come from the ViewModel** — that's a state-hoisting violation that also pessimizes recomposition.
- **No synchronous I/O in `Application.onCreate()`** — disk reads, network calls, Firebase config fetch. Defer to a background executor or App Startup initializer.
- **No benchmarking on a debug build** and claiming a result.
- **No `CompositionLocal` for scalar state that changes frequently** — every reader recomposes on every change.
