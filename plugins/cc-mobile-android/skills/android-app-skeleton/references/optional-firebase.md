# Reference — INCLUDE_FIREBASE additions

Only emit when `INCLUDE_FIREBASE` is true. Firebase auto-initializes via `FirebaseInitProvider` as soon as a `google-services.json` is present for the current flavor. The collection toggle in `Application.onCreate()` and the actual `logEvent` calls live in `core/data/analytics/FirebaseAnalyticsTracker` — see [core-data.md](core-data.md) ("Analytics" section).

The Application class itself is the unified template (no Firebase-specific variant); it talks to `AnalyticsTracker` (the domain interface) which Hilt resolves to `FirebaseAnalyticsTracker` when this flag is on.

The Firebase artifacts in `app/build.gradle.kts` use `com.google.firebase:firebase-crashlytics` / `firebase-analytics` (no `-ktx` suffix) — the `*-ktx` variants have been empty stubs since Firebase BOM 32.5.

## Per-flavor `google-services.json`

Drop `google-services.json` into `app/src/dev/` and `app/src/prod/`. Never commit to `app/` root; the plugin will apply to every variant. The `tasks.matching` block in `app/build.gradle.kts` (see [app-module.md](app-module.md)) makes the build skip the google-services task per-variant until the matching JSON is present, so `./gradlew :app:installDevDebug` works end-to-end on a freshly scaffolded project.
