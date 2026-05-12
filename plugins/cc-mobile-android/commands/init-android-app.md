---
description: Scaffold a fresh Android app with this project's conventions — Kotlin, Compose, Clean Architecture, Hilt, Retrofit, Coroutines/Flow, Navigation Compose with typed routes, Material 3, bottom-nav Home + Feed/Profile tabs, and a domain-layer AnalyticsTracker abstraction with Firebase or no-op impls.
argument-hint: "[package_id]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task, AskUserQuestion, WebFetch
---

# /init-android-app

You are scaffolding a brand-new Android application from scratch. This command is intentionally a **thin orchestrator** — every file template, execution step, hard rule, and post-init checklist lives in `.claude/skills/android-app-skeleton/SKILL.md`. This file owns three things only:

1. The Phase 0 questionnaire (skeleton can't ask questions).
2. The Phase 1.5 version-resolution loop (`maven-metadata.xml` walk).
3. The Phase 2/3 procedure pointers into the skeleton + smoke validation.

If you find yourself re-explaining file structure, package layout, or template content here, stop — edit the skeleton instead and link to it from this file.

---

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
8. **Flavors**: `dev` + `prod` (default yes). Flavor names are **fixed** to `dev` and `prod` in this scaffold so the per-flavor `google-services.json` story (`app/src/dev/`, `app/src/prod/`) and the build-time `processGoogleServices` guard line up with what `INCLUDE_FIREBASE` expects. To rename or add flavors (e.g. `staging`), do it after scaffold via `android-build-expert` — those edits also need the matching `app/src/<flavor>/` source set, the `applicationIdSuffix`/`versionNameSuffix` per flavor, and any Firebase-JSON drops to follow. If yes, drives the `productFlavors` block in Gradle. If no, the `buildConfigField("String", "API_BASE_URL", ...)` line in `defaultConfig` (the `FLAVORS_OFF` comment in the skeleton's `app/build.gradle.kts`) gets uncommented and the `productFlavors` block is omitted.
9. **API base URL(s)** — drives `{{API_BASE_URL_DEV}}` and `{{API_BASE_URL_PROD}}` placeholders. Defaults: `https://api.dev.example.com/` and `https://api.example.com/`. **Trailing slash is required** by Retrofit; reject input that's missing it. If flavors are off (Q8), ask for one URL only and write it into the `defaultConfig.buildConfigField` line. The runtime client (`data/network/ApiClientFactory.kt`) reads `BuildConfig.API_BASE_URL`, so this is the single source of truth — don't sprinkle hard-coded URLs.

Confirm the plan in one short paragraph. Proceed only after confirmation.

## Phase 1 — Load the blueprint

**Read `.claude/skills/android-app-skeleton/SKILL.md` in full.** It is the only source of truth for placeholders, execution order, file templates, hard rules, and post-scaffold checklist. Don't paraphrase or summarize the skill in this command — link to it.

## Phase 1.5 — Resolve all versions online

The skill's `[versions]` block is intentionally placeholder-only (`<latest-stable>`). Every ref is resolved at scaffold time by reading the registry's `maven-metadata.xml` — that's why the command works months from now without needing edits when libraries cut new releases.

For each ref, `WebFetch` the URL below and pick the newest version that is **not** suffixed `-alpha`, `-beta`, `-RC`, `-rc`, `-dev`, `-SNAPSHOT`, or `-eap`. The interesting node in `maven-metadata.xml` is `<versioning><release>` (preferred) or the last `<version>` under `<versions>` after pre-release filtering.

| Ref | URL |
|---|---|
| `agp` | `https://dl.google.com/android/maven2/com/android/tools/build/gradle/maven-metadata.xml` |
| `kotlin` | `https://repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib/maven-metadata.xml` |
| `kotlin-compose` (sanity check only — pinned to `kotlin` ref) | `https://repo1.maven.org/maven2/org/jetbrains/kotlin/compose-compiler-gradle-plugin/maven-metadata.xml` (used to confirm the artifact exists at the resolved Kotlin version) |
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
| `coil` (Coil 3 — both `coil-compose` + `coil-network-okhttp` ride this single ref) | `https://repo1.maven.org/maven2/io/coil-kt/coil3/coil-compose/maven-metadata.xml` |
| `datastore` | `https://dl.google.com/android/maven2/androidx/datastore/datastore-preferences/maven-metadata.xml` |
| `room` | `https://dl.google.com/android/maven2/androidx/room/room-runtime/maven-metadata.xml` |
| `firebase-bom` | `https://dl.google.com/android/maven2/com/google/firebase/firebase-bom/maven-metadata.xml` |
| `google-services` | `https://dl.google.com/android/maven2/com/google/gms/google-services/maven-metadata.xml` |
| `firebase-crashlytics-plugin` | `https://dl.google.com/android/maven2/com/google/firebase/firebase-crashlytics-gradle/maven-metadata.xml` |
| `junit` | `https://repo1.maven.org/maven2/junit/junit/maven-metadata.xml` |
| `mockk` | `https://repo1.maven.org/maven2/io/mockk/mockk/maven-metadata.xml` |
| `turbine` | `https://repo1.maven.org/maven2/app/cash/turbine/turbine/maven-metadata.xml` |
| `compileSdk` / `targetSdk` | Use the latest stable Android API level (currently the highest API the user's installed `compileSdk` allows; if unsure, run `ls $ANDROID_HOME/platforms` and pick the highest `android-N`). Hard-code that integer in `app/build.gradle.kts`. |

**Resolution order matters.** Resolve `kotlin` *before* `ksp` (KSP must match Kotlin's patch version) and *before* `coroutines` (coroutines major must match Kotlin major). The Compose Compiler plugin (`kotlin-compose`) does not need a separate fetch — its catalog entry rides the `kotlin` ref. Run independent fetches in parallel where you can.

**After resolution, sanity-check against the skill's "Compatibility traps" table.** If a known trap pattern matches the resolved set (e.g. AGP 9 + Hilt < 2.59), bump the affected ref to the next available version that clears the trap and rerun the affected fetch. Do not silently downgrade.

**Do not fall back to hard-coded defaults if a fetch fails.** Stop and surface the failure (network down, registry returning HTML, version filter empty after stripping pre-releases) — proceeding with stale numbers is exactly the failure mode this phase is meant to prevent.

## Phase 2 — Execute the scaffold

Follow the **skeleton skill's "Execution order" section verbatim** (`.claude/skills/android-app-skeleton/SKILL.md` → "Execution order"). Substitute the placeholders from Phase 0 + Phase 1.5. The skill is the source of truth for which files to create, in which order, and with what content; do not duplicate that list here.

When you reach step 9 of the skill (compile + assemble + run unit tests), run **all three** commands — `compileDebugKotlin` alone is not sufficient. The full `assembleDevDebug` is the gate that catches missing Gradle plugins (e.g. the Compose Compiler plugin), unresolved dependencies, and manifest merger errors:

```
./gradlew :app:compileDebugKotlin
./gradlew :app:assembleDevDebug      # or :app:assembleDebug if flavors off
./gradlew :app:testDebugUnitTest
```

If any of these fails, print the error and stop. Do not "fix and continue" silently — the user needs to see what didn't work and decide.

## Phase 3 — Post-init checklist

The skeleton owns the "Post-scaffold manual steps" block — print exactly what's there, with values substituted (flavor names, package id). Don't compose your own.

## Ground rules

- Stay inside the `ClaudeCodeMobile` workspace unless the user points to a different parent directory.
- One command per Bash call where it matters (`gradle wrapper`, `./gradlew compileDebugKotlin`, `./gradlew assembleDevDebug`, `./gradlew testDebugUnitTest`).
- Never commit.
- Do not scaffold real features — stop once the Home + Feed + Profile tabs render and the FeedViewModelTest passes.
- Do not create unsolicited docs.

## When to say no

- Target dir already contains `settings.gradle.kts` → switch to the merge flow (Phase 0). Don't proceed without the user picking abort / subdirectory / merge explicitly.
- `java`, `gradle`, or Android SDK not on PATH → stop and tell the user.
- Resolved `agp` < 9.0 and the user hasn't asked for AGP 8.x explicitly → stop and surface the floor mismatch (the templates are AGP 9-shaped); the skill's "Escape hatch: AGP 8.x" callout describes the deltas if the user confirms.
- User picks Firebase without having a project set up → proceed; the `onlyIf` guard keeps the build green until the JSON arrives, but flag the manual drop.
- API base URL doesn't end with `/` → reject and re-ask. Retrofit will throw at construction time otherwise.
