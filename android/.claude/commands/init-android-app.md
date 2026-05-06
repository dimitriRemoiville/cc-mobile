---
description: Scaffold a fresh Android app with this project's conventions — Kotlin, Compose, Clean Architecture, Hilt, Retrofit, Coroutines/Flow, Navigation Compose with typed routes, Material 3, bottom-nav Home + Feed/Profile tabs, and a domain-layer AnalyticsTracker abstraction with Firebase or no-op impls.
argument-hint: "[package_id]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task, AskUserQuestion, WebFetch
---

# /init-android-app

You are scaffolding a brand-new Android application from scratch. **Nothing is generated until Phase 0 is answered** — flags materially change the generated files.

## Phase 0 — Gather inputs

**Detect the target directory state first.** Before asking anything else, scan for `settings.gradle*`, `build.gradle*`, or an `app/` module:

- **Greenfield** (no Gradle files) → run the full questionnaire below.
- **Existing scaffold** (Gradle files present) → run the *merge* flow: ask whether to (a) **abort**, (b) **scaffold into a subdirectory**, or (c) **merge** — i.e. align the existing project with the skill's conventions in place. If the user picks merge, do **not** overwrite `app/build.gradle.kts`, `settings.gradle.kts`, or any existing source files automatically. Read the existing files, diff them against the skill, and present a short plan listing exactly which files would be created vs. patched, then wait for explicit go-ahead. Many users hit this command on a fresh Android Studio template they want upgraded — give them a path that doesn't wipe their work.

Use `AskUserQuestion` to collect (propose defaults, let user confirm or override in one round-trip):

1. **App display name** (free-text, e.g. "My App").
2. **Application id / package id** (reverse-DNS, e.g. `com.example.myapp`). If `$ARGUMENTS` is provided, use as default.
3. **Min SDK** (default 26) / **Target & Compile SDK** — *resolve* the current latest stable platform SDK at scaffold time (do not hard-code an integer like `35`); surface the resolved value and let the user override. If the user picks Min SDK ≥ 31, the dynamic-color guard in `AppTheme.kt` becomes redundant — drop it; otherwise it ships in by default.
4. **Include Room persistence?** (yes/no) — drives `INCLUDE_ROOM`.
5. **Include DataStore?** (yes/no, default yes) — drives `INCLUDE_DATASTORE`.
6. **Include Firebase (Crashlytics + Analytics)?** (yes/no) — drives `INCLUDE_FIREBASE`. With this on, the analytics layer's Hilt module binds `AnalyticsTracker` to `FirebaseAnalyticsTracker`; with it off, it binds to `NoopAnalyticsTracker`. The Application class is the same either way (it injects the interface). The scaffold also installs a `tasks.matching { processGoogleServices }.onlyIf { ... }` guard so the project still compiles + installs before `google-services.json` arrives.
7. **Stub release signing config?** (yes/no, default yes) — emits the `keystore.properties`-driven `signingConfigs` block plus a committed `keystore.properties.example`. The block is a no-op until the user fills in the file.
8. **Flavors**: `dev` + `prod` (default yes). If yes, drives flavor blocks in Gradle.

Confirm the plan in one short paragraph. Proceed only after confirmation.

## Phase 1 — Load the blueprint

Read `.claude/skills/android-app-skeleton/SKILL.md` in full. It is the source of truth for:

- The execution order.
- Every file template (`build.gradle.kts`, `libs.versions.toml`, `AndroidManifest.xml`, source files under `app/src/main/java`, tests under `app/src/test/java`).
- Placeholders: `{{APP_NAME}}`, `{{APP_CLASS}}`, `{{PACKAGE_ID}}`, `{{PACKAGE_PATH}}`, `{{APP_DISPLAY_NAME}}`.
- Flag blocks: `INCLUDE_ROOM`, `INCLUDE_DATASTORE`, `INCLUDE_FIREBASE`.
- Hard rules (no `kapt` — KSP only; no string routes; no `android.*` imports inside the `domain` package; Compose BOM — never pin Compose libs individually).
- AGP-version baseline. The templates assume **AGP 9 / Kotlin 2.2 / JDK 17**; the skill calls out the AGP 8.x deltas in a callout. Don't silently retarget.

Follow templates verbatim — substitute placeholders. The only acceptable divergence is a documented AGP-version delta; if you find yourself improvising more, stop and surface what you're seeing.

## Phase 1.5 — Resolve all versions online

The skill's `[versions]` block is intentionally placeholder-only (`<latest-stable>`). Every ref is resolved at scaffold time by reading the registry's `maven-metadata.xml` — that's why the command works months from now without needing edits when libraries cut new releases.

For each ref, `WebFetch` the URL below and pick the newest version that is **not** suffixed `-alpha`, `-beta`, `-RC`, `-rc`, `-dev`, `-SNAPSHOT`, or `-eap`. The interesting node in `maven-metadata.xml` is `<versioning><release>` (preferred) or the last `<version>` under `<versions>` after pre-release filtering.

| Ref | URL |
|---|---|
| `agp` | `https://dl.google.com/android/maven2/com/android/tools/build/gradle/maven-metadata.xml` |
| `kotlin` | `https://repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib/maven-metadata.xml` |
| `ksp` | `https://repo1.maven.org/maven2/com/google/devtools/ksp/symbol-processing-api/maven-metadata.xml` — then filter to versions starting with `<resolved-kotlin>-` (e.g. `2.2.10-`); KSP versioning is `<kotlinVersion>-<kspPatch>`. |
| `coroutines` / `coroutines-test` | `https://repo1.maven.org/maven2/org/jetbrains/kotlinx/kotlinx-coroutines-core/maven-metadata.xml` (use the same value for both refs). |
| `hilt` | `https://repo1.maven.org/maven2/com/google/dagger/hilt-android/maven-metadata.xml` |
| `hilt-navigation-compose` | `https://dl.google.com/android/maven2/androidx/hilt/hilt-navigation-compose/maven-metadata.xml` |
| `compose-bom` | `https://dl.google.com/android/maven2/androidx/compose/compose-bom/maven-metadata.xml` |
| `navigation-compose` | `https://dl.google.com/android/maven2/androidx/navigation/navigation-compose/maven-metadata.xml` |
| `lifecycle` | `https://dl.google.com/android/maven2/androidx/lifecycle/lifecycle-runtime-ktx/maven-metadata.xml` |
| `activity-compose` | `https://dl.google.com/android/maven2/androidx/activity/activity-compose/maven-metadata.xml` |
| `androidx-core-ktx` | `https://dl.google.com/android/maven2/androidx/core/core-ktx/maven-metadata.xml` |
| `retrofit` | `https://repo1.maven.org/maven2/com/squareup/retrofit2/retrofit/maven-metadata.xml` |
| `okhttp` | `https://repo1.maven.org/maven2/com/squareup/okhttp3/okhttp/maven-metadata.xml` |
| `kotlinx-serialization` | `https://repo1.maven.org/maven2/org/jetbrains/kotlinx/kotlinx-serialization-json/maven-metadata.xml` |
| `datastore` | `https://dl.google.com/android/maven2/androidx/datastore/datastore-preferences/maven-metadata.xml` |
| `room` | `https://dl.google.com/android/maven2/androidx/room/room-runtime/maven-metadata.xml` |
| `firebase-bom` | `https://dl.google.com/android/maven2/com/google/firebase/firebase-bom/maven-metadata.xml` |
| `google-services` | `https://dl.google.com/android/maven2/com/google/gms/google-services/maven-metadata.xml` |
| `firebase-crashlytics-plugin` | `https://dl.google.com/android/maven2/com/google/firebase/firebase-crashlytics-gradle/maven-metadata.xml` |
| `junit` | `https://repo1.maven.org/maven2/junit/junit/maven-metadata.xml` |
| `mockk` | `https://repo1.maven.org/maven2/io/mockk/mockk/maven-metadata.xml` |
| `turbine` | `https://repo1.maven.org/maven2/app/cash/turbine/turbine/maven-metadata.xml` |
| `compileSdk` / `targetSdk` | Use the latest stable Android API level (currently the highest API the user's installed `compileSdk` allows; if unsure, run `ls $ANDROID_HOME/platforms` and pick the highest `android-N`). Hard-code that integer in `app/build.gradle.kts`. |

**Resolution order matters.** Resolve `kotlin` *before* `ksp` (KSP must match Kotlin's patch version) and *before* `coroutines` (coroutines major must match Kotlin major). Run independent fetches in parallel where you can.

**After resolution, sanity-check against the skill's "Compatibility traps" table.** If a known trap pattern matches the resolved set (e.g. AGP 9 + Hilt < 2.59), bump the affected ref to the next available version that clears the trap and rerun the affected fetch. Do not silently downgrade.

**Do not fall back to hard-coded defaults if a fetch fails.** Stop and surface the failure (network down, registry returning HTML, version filter empty after stripping pre-releases) — proceeding with stale numbers is exactly the failure mode this phase is meant to prevent.

## Phase 2 — Execute the scaffold

Follow the skill's procedure:

1. Create the project directory and the Gradle structure:
   - Root: `settings.gradle.kts`, `build.gradle.kts`, `gradle.properties` (with `android.disallowKotlinSourceSets=false` for AGP 9), `gradle/libs.versions.toml`, `gradle/wrapper/gradle-wrapper.properties`, `gradle/gradle-daemon-jvm.properties` (toolchain 21 via foojay).
   - Single module: `:app` only. Clean Architecture layers live as packages (`domain/`, `data/`, `ui/`), not as separate Gradle modules — see the skill's "Module or package?" note. Extract modules later if the app grows into multi-feature territory or a shared library appears.
2. Initialize the Gradle wrapper: `gradle wrapper --gradle-version <latest-stable>` (if `gradle` is on PATH), or copy in a known-good `gradle-wrapper.jar` + `gradlew` + `gradlew.bat` from a local cache. Bail if neither is available.
3. Write `libs.versions.toml` using the skill as the **shape** (which refs to include, which libraries/plugins to alias). All version values come from Phase 1.5's resolution table — never copy the skill's `<latest-stable>` placeholders verbatim, never invent numbers from training data. After resolution, sanity-check the set against the skill's "Compatibility traps" table. The `kotlin-android` plugin alias is intentionally absent on AGP 9 (built-in Kotlin) — only re-add it if the resolved AGP < 9.
4. Write root `build.gradle.kts` (no `kotlin.android` plugin alias under AGP 9) and `settings.gradle.kts` (the latter includes `:app` only).
5. Write `app/build.gradle.kts` with the AGP 9 idioms from the skill: `kotlin { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }` (not `kotlinOptions { jvmTarget = "17" }`), `buildFeatures { buildConfig = true }` (always — needed by the analytics collection toggle), the resolved `compileSdk` integer, the optional `signingConfigs.release` block reading from `keystore.properties` (only if Phase 0 Q7 = yes), and — under `INCLUDE_FIREBASE` — the `tasks.matching { processGoogleServices }.onlyIf { ... }` skip-if-missing guard. No `project(":core:*")` entries.
6. Write `AndroidManifest.xml`, `strings.xml` (with `app_name`, `tab_feed`, `tab_profile`), themes, one launcher icon set (mipmap-anydpi-v26 vector placeholder).
7. Write source files under `app/src/main/java/{{PACKAGE_PATH}}/`:
   - `{{APP_CLASS}}.kt` (single Hilt Application variant — injects `AnalyticsTracker` and calls `setCollectionEnabled(!BuildConfig.DEBUG)` regardless of `INCLUDE_FIREBASE`; with the no-op tracker it's harmless), `MainActivity.kt`.
   - `ui/theme/AppTheme.kt` (Material 3, dynamic-color guarded by `Build.VERSION.SDK_INT >= S` unless Min SDK ≥ 31).
   - `ui/home/HomeScreen.kt` (Scaffold + `NavigationBar` + nested `NavHost`; tabs are `@Serializable HomeRoute.Feed` and `HomeRoute.Profile`; selection via `NavDestination.hasRoute(KClass)`).
   - `ui/home/feed/FeedScreen.kt` + `FeedViewModel.kt` + `FeedState`. The VM injects `AnalyticsTracker` and calls `analytics.track(AnalyticsEvent.FeedViewed)` from `init`.
   - `ui/home/profile/ProfileScreen.kt` + `ProfileViewModel.kt` + `ProfileState`. Same pattern, tracks `AnalyticsEvent.ProfileViewed`.
   - `ui/common/TrackScreen.kt` — `@Composable` helper that fires an event once on entry via `LaunchedEffect`. Useful for screens whose VMs survive nav transitions.
   - `navigation/AppNavGraph.kt` (single `@Serializable Home` destination — bottom-nav lives nested inside `HomeScreen`, not at the top level).
   - `domain/Outcome.kt`, `domain/DomainError.kt`. Treat the `domain/` package as Android-free by convention — no `android.*` imports here, ever.
   - `domain/analytics/AnalyticsTracker.kt` (interface), `domain/analytics/AnalyticsEvent.kt` (sealed taxonomy: `HomeViewed`, `FeedViewed`, `ProfileViewed`, `ItemTapped(itemId)`, `ScreenOpenedFromDeepLink(route)`).
   - `data/network/ApiClientFactory.kt`, `data/network/SampleApi.kt` (interface + `@Serializable PingDto`), `data/network/RemoteDataSource.kt` (maps DTOs + exceptions to `Outcome` + `DomainError`).
   - `data/di/DataModule.kt` — Hilt `@Module` providing Retrofit + `SampleApi`.
   - `data/analytics/NoopAnalyticsTracker.kt` (always emit), `data/analytics/AnalyticsModule.kt` (always emit; binds `AnalyticsTracker` to the Firebase or no-op impl based on `INCLUDE_FIREBASE`).
   - (Conditional, `INCLUDE_FIREBASE`) `data/analytics/FirebaseAnalyticsTracker.kt`.
   - (Conditional, `INCLUDE_ROOM`) `data/persistence/` — Room DB, entities, DAOs, repository.
   - (Conditional, `INCLUDE_DATASTORE`) `data/datastore/` — DataStore typed preferences.
8. Write tests under `app/src/test/java/{{PACKAGE_PATH}}/`:
   - `domain/OutcomeMapTest.kt` — anchors the framework-free convention for the domain layer.
   - `ui/home/feed/FeedViewModelTest.kt` — JUnit 4 + MockK + Turbine. Verifies (a) the initial UiState shape and (b) that the VM tracks `AnalyticsEvent.FeedViewed` on `init` (analytics-mocking demo).
9. (If Phase 0 Q7 = yes) Write `keystore.properties.example` at the repo root and add `keystore.properties`, `*.keystore`, and `/app/src/*/google-services.json` to `.gitignore`.
10. Run `./gradlew :app:compileDebugKotlin` to validate. If it fails, print the error and stop.
11. Run `./gradlew :app:testDebugUnitTest`.
12. Print the manual setup note — release signing key generation (`keytool -genkey ...`), per-flavor `applicationIdSuffix`, CI, Play Console metadata, and "extract `domain/` + `data/` to `:core:*` modules once you have real coupling pressure" as a followup.

## Phase 3 — Post-init checklist

Print a concise checklist:

```
Scaffold complete. Next steps:

☐ Generate a release keystore and copy keystore.properties.example → keystore.properties (gitignored).
   keytool -genkey -v -keystore release.keystore -alias release -keyalg RSA -keysize 2048 -validity 10000
   The signing config in app/build.gradle.kts auto-wires once keystore.properties exists.
☐ [if Firebase] drop google-services.json into app/src/dev/ and app/src/prod/.
   The processGoogleServices task is gated by an onlyIf guard, so the build already works
   end-to-end without it — but Crashlytics/Analytics won't actually report until the JSON arrives.
☐ [if Room] run `./gradlew :app:kspDevDebugKotlin` — confirm app/schemas/ is populated.
☐ Replace the Feed and Profile tab placeholders with your first real features.
   The tabs live under ui/home/<tab>/ as typed HomeRoute.<Tab> destinations.
☐ Add new analytics events as sealed entries in domain/analytics/AnalyticsEvent.kt
   (don't sprinkle magic strings — the sealed type is the source of truth).

Build it:
  ./gradlew :app:installDevDebug
  ./gradlew :app:testDebugUnitTest
```

## Ground rules

- Stay inside the `ClaudeCodeMobile` workspace unless the user points to a different parent directory.
- One command per Bash call where it matters (`gradle wrapper`, `./gradlew compileDebugKotlin`, `./gradlew testDebugUnitTest`).
- Never commit.
- Do not scaffold real features — stop once the Home + Feed + Profile tabs render and the FeedViewModelTest passes.
- Do not create unsolicited docs.

## When to say no

- Target dir already contains `settings.gradle.kts` → switch to the merge flow (Phase 0). Don't proceed without the user picking abort / subdirectory / merge explicitly.
- `java`, `gradle`, or Android SDK not on PATH → stop and tell the user.
- Resolved `agp` < 9.0 and the user hasn't asked for AGP 8.x explicitly → stop and surface the floor mismatch (the templates are AGP 9-shaped).
- User picks Firebase without having a project set up → proceed; the `onlyIf` guard keeps the build green until the JSON arrives, but flag the manual drop.
