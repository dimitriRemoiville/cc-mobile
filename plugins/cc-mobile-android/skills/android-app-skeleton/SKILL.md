---
name: android-app-skeleton
description: Authoritative blueprint for scaffolding a brand-new Android app with this project's conventions. Used by /init-android-app. Contains every file template, placeholder list, feature-flag block, and the procedure to emit a runnable Home screen with bottom-nav tabs (Feed + Profile) and a clean-architecture analytics layer.
---

# Android app skeleton

This file is the template registry. The `/init-android-app` command reads this skill top-to-bottom and substitutes placeholders before writing files. Follow templates verbatim — the whole point of the skeleton is reproducibility. The only acceptable divergence is a documented AGP-version delta (see "AGP 9 vs AGP 8.x" callout below). If you find yourself improvising more than that, stop and surface what you're seeing instead.

**Target floor: AGP 9 / Kotlin 2.2 / JDK 17.** Older toolchains (AGP 8.x) require the deltas listed in the callout. Don't silently retarget — fail loudly if the resolved versions disagree with the floor table.

## Placeholders

| Placeholder | Meaning | Example |
|---|---|---|
| `{{APP_NAME}}` | Gradle project folder name, lowercase kebab or snake | `my_app` |
| `{{APP_CLASS}}` | `Application` subclass name in PascalCase | `MyApp` |
| `{{PACKAGE_ID}}` | applicationId / root package | `com.example.myapp` |
| `{{PACKAGE_PATH}}` | slash form of package id | `com/example/myapp` |
| `{{APP_DISPLAY_NAME}}` | Human-facing name | `My App` |
| `{{API_BASE_URL_DEV}}` | Dev-flavor API base URL (trailing slash required by Retrofit) | `https://api.dev.example.com/` |
| `{{API_BASE_URL_PROD}}` | Prod-flavor API base URL (trailing slash required by Retrofit) | `https://api.example.com/` |

## Feature flags

| Flag | Adds |
|---|---|
| `INCLUDE_ROOM` | Room module + entities/DAO/DB, migration skeleton, schema export |
| `INCLUDE_DATASTORE` | DataStore module + typed prefs |
| `INCLUDE_FIREBASE` | google-services plugin + Crashlytics + Analytics init |

## Layout

Single Gradle module, `:app`. **Feature-first** package layout — each feature is a top-level package containing the layers it actually needs (`ui/`, `domain/`, `data/`). Cross-feature plumbing lives under `core/`. This matches `android-architecture` and is what `/new-feature` and `/add-screen` produce.

```
app/src/main/java/{{PACKAGE_PATH}}/
├── {{APP_CLASS}}.kt                  # Application
├── MainActivity.kt                   # single Activity host
├── core/                             # cross-feature plumbing
│   ├── domain/                       # Outcome, DomainError, analytics interface (framework-free)
│   ├── data/                         # networking + analytics impls (knows frameworks)
│   ├── ui/theme/                     # AppTheme, color schemes
│   └── navigation/                   # AppNavGraph (top-level routes)
├── home/ui/                          # the bottom-nav shell feature (no data/domain — pure UI)
├── feed/                             # tab feature, full feature-first shape
│   ├── data/{repository,di}/
│   ├── domain/{model,repository,usecase}/
│   └── ui/                           # UiState, ViewModel, Screen, Route
└── profile/                          # tab feature, full feature-first shape
    ├── data/{repository,di}/
    ├── domain/{model,repository,usecase}/
    └── ui/                           # UiState, ViewModel, Screen, Route
```

Each new feature added later mirrors `feed/` and `profile/` — `<feature>/{ui,domain,data}/` with only the layers it needs. The shell feature (`home/`) knows about its tab features; tab features don't know about each other. Feed and Profile in the scaffold each ship the full three-layer shape so the result lines up with what `/new-feature` and `/add-screen` produce — no special-casing the first two tabs.

Why feature-first inside a single module?
- **Code locality.** Everything for a screen — UI, state, repository, mapping — lives next to itself. New contributors find code by feature name, not by guessing which `data/` subfolder.
- **Refactor pressure.** When a feature outgrows the package, promoting it to a `:feature:<name>` Gradle module is mechanical. Layer-first packages don't promote cleanly.
- **Single-module tax stays low.** No extra `build.gradle.kts`, no `project(":core:*")` wiring, no slower first build until you actually want module-level isolation. See `android-architecture/SKILL.md` → "Module or package?".

## Execution order

1. Create directory `{{APP_NAME}}/` with Gradle wrapper.
2. Write `settings.gradle.kts`, root `build.gradle.kts`, `gradle.properties`, `gradle/libs.versions.toml`.
3. Write `app/build.gradle.kts` (single module — it carries all runtime deps).
4. Write `AndroidManifest.xml`, `strings.xml` (with tab labels), themes, launcher icons.
5. Write `core/domain/` — `Outcome`, `DomainError`, **`analytics/AnalyticsTracker` interface + `AnalyticsEvent` sealed taxonomy** (always emitted; the analytics interface is part of the domain so use cases / VMs depend on the abstraction even when Firebase is absent).
6. Write `core/data/` — sample API + `RemoteDataSource`, **`Outcomes.kt` (canonical `Result<T>.toOutcome(...)` adapter + `toDomainError(...)` mapper)**, **`network/di/NetworkModule.kt` (Hilt providers for `OkHttpClient`, `Json`, `Retrofit`, `SampleApi` — DEBUG-gated logging; one source of truth for the HTTP stack so Coil reuses the same client)**, **`analytics/` module wiring `AnalyticsTracker` to `NoopAnalyticsTracker` (always) or `FirebaseAnalyticsTracker` (`INCLUDE_FIREBASE`)**. Add `core/data/persistence/` + `core/data/datastore/` (with their own DI modules) behind their flags.
7. Write `core/ui/theme/AppTheme.kt` and `core/navigation/AppNavGraph.kt` (top-level nav with `Home` as start destination).
8. Write the features — `{{APP_CLASS}}` Application (Hilt + `SingletonImageLoader.Factory` for Coil), `MainActivity`, **`home/ui/{HomeScreen,HomeViewModel}.kt` (bottom NavigationBar + nested NavHost; VM fires `AnalyticsEvent.HomeViewed` from `init { }`)**, and the two demo tabs in their full feature-first shape: `feed/{data,domain,ui}/` and `profile/{data,domain,ui}/` — each tab ships a `RepositoryImpl` (stub data wrapped in `Outcome.Success`), a domain `Repository` interface + `UseCase`, a Hilt `<Feature>DataModule` binding the impl, and `UiState` / `ViewModel` / `Screen` / `Route` under `ui/`. ViewModels expose user actions as discrete public functions (`fun retry()`, `fun submit(...)`), matching Google's [Now in Android](https://github.com/android/nowinandroid); escalate to a sealed `<Screen>Action.kt` only when a screen has ≥5 distinct interactions.
9. Write `:app` tests — `core/domain/OutcomeMapTest.kt`, `feed/ui/FeedViewModelTest.kt` and `profile/ui/ProfileViewModelTest.kt` (each mocks `AnalyticsTracker` + the feature use case and verifies the `init { }` analytics event fires), plus the Compose UI tests `feed/ui/FeedScreenTest.kt` and `profile/ui/ProfileScreenTest.kt` under `app/src/androidTest/`. The androidTest pair anchors the Route + Screen split: each test drives the **stateless** `<Feature>Screen` directly, not the Route — no Hilt setup needed.
10. **Compile + assemble + run unit tests.** Run `:app:compileDebugKotlin`, then **`:app:assembleDevDebug`** (the full assemble — this is the gate that catches missing Gradle plugins, unresolved deps, manifest merger errors), then `:app:testDebugUnitTest`. `compileDebugKotlin` alone is not sufficient. The Compose UI tests run via `:app:connectedDebugAndroidTest` when an emulator/device is attached; if none is available, leave them ready-to-run rather than blocking the scaffold.
11. Emit manual setup notes (signing, flavor stubs, Firebase files).

---

## Root files

### `settings.gradle.kts`

```kts
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode = RepositoriesMode.FAIL_ON_PROJECT_REPOS
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "{{APP_NAME}}"

include(":app")
```

### `build.gradle.kts` (root)

```kts
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.ksp) apply false
    alias(libs.plugins.hilt) apply false
    // INCLUDE_FIREBASE: alias(libs.plugins.google.services) apply false
    // INCLUDE_FIREBASE: alias(libs.plugins.firebase.crashlytics) apply false
}
```

`org.jetbrains.kotlin.android` is **not** declared at the root: AGP 9 ships a built-in Kotlin runtime and registers the `kotlin` extension itself; applying the standalone plugin throws `Cannot add extension with name 'kotlin', as there is an extension already registered`. `android.library` / `kotlin.jvm` aliases are intentionally omitted from the catalog too — there are no library / pure-JVM modules yet. Add aliases when you extract `:core:*` modules (a commented stub at the bottom of `[plugins]` in `libs.versions.toml` marks where they go).

> **AGP 8.x note.** If you've pinned to AGP 8.x for some reason, you must add `alias(libs.plugins.kotlin.android) apply false` here and the matching `alias(libs.plugins.kotlin.android)` in `app/build.gradle.kts`. The rest of the templates assume AGP 9.

### `gradle.properties`

```properties
org.gradle.jvmargs=-Xmx4g -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.configuration-cache=true
kotlin.code.style=official
android.useAndroidX=true
android.nonTransitiveRClass=true
# Required by AGP 9: KSP (and other plugins) register generated source dirs
# via kotlin.sourceSets, which AGP 9's built-in Kotlin disallows by default.
# Without this flag, every Hilt/Room scaffold dies at config time.
android.disallowKotlinSourceSets=false
```

### `gradle/gradle-daemon-jvm.properties`

Pins the Gradle daemon JVM via the toolchain mechanism (foojay resolver). Preferred over relying on the user's `JAVA_HOME` — every contributor lands on the same JDK.

```properties
toolchainVersion=21
```

(JDK 21 runs the Gradle daemon; the project still targets bytecode 17 — see `compileOptions` and `kotlin { compilerOptions { jvmTarget } }` in `app/build.gradle.kts`.)

### `gradle/libs.versions.toml`

**Do not copy the version strings below verbatim.** The `[versions]` block below shows the *shape* — which version refs the scaffold uses. When generating the file for a new project, resolve each version to the latest stable that satisfies the floor-constraint table further down, then write those into the file.

In practice: open the Gradle Plugin Portal / Maven Central for each `[versions]` key, take the newest non-alpha/non-RC release, and substitute it in. If a resolved version falls below its listed floor, stop and surface the blocker — something is pinning the project below the line the rest of the skill assumes.

```toml
[versions]
agp = "<latest-stable>"
kotlin = "<latest-stable>"
ksp = "<kotlin>-<ksp-patch>"             # must match the resolved kotlin version
coroutines = "<latest-stable>"
hilt = "<latest-stable>"
hilt-navigation-compose = "<latest-stable>"
compose-bom = "<latest-stable>"
navigation-compose = "<latest-stable>"
lifecycle = "<latest-stable>"
activity-compose = "<latest-stable>"
androidx-core-ktx = "<latest-stable>"
retrofit = "<latest-stable>"               # >= 2.10 — bundles Square's kotlinx-serialization converter
okhttp = "<latest-stable>"
kotlinx-serialization = "<latest-stable>"
coil = "<latest-stable>"                   # Coil 3.x — `io.coil-kt.coil3` group, Compose-first
datastore = "<latest-stable>"
room = "<latest-stable>"
firebase-bom = "<latest-stable>"
google-services = "<latest-stable>"
firebase-crashlytics-plugin = "<latest-stable>"
junit = "<latest-stable>"
androidx-test-ext-junit = "<latest-stable>"
mockk = "<latest-stable>"
turbine = "<latest-stable>"
coroutines-test = "<latest-stable>"

[libraries]
androidx-core-ktx = { module = "androidx.core:core-ktx", version.ref = "androidx-core-ktx" }
androidx-activity-compose = { module = "androidx.activity:activity-compose", version.ref = "activity-compose" }
androidx-lifecycle-runtime-ktx = { module = "androidx.lifecycle:lifecycle-runtime-ktx", version.ref = "lifecycle" }
androidx-lifecycle-viewmodel-compose = { module = "androidx.lifecycle:lifecycle-viewmodel-compose", version.ref = "lifecycle" }

compose-bom = { module = "androidx.compose:compose-bom", version.ref = "compose-bom" }
compose-ui = { module = "androidx.compose.ui:ui" }
compose-material3 = { module = "androidx.compose.material3:material3" }
# Bottom-nav icons (Home, Person, etc.) come from the core icon set; pinned by the BOM.
compose-material-icons-core = { module = "androidx.compose.material:material-icons-core" }
compose-tooling = { module = "androidx.compose.ui:ui-tooling" }
compose-tooling-preview = { module = "androidx.compose.ui:ui-tooling-preview" }

navigation-compose = { module = "androidx.navigation:navigation-compose", version.ref = "navigation-compose" }

hilt-android = { module = "com.google.dagger:hilt-android", version.ref = "hilt" }
hilt-compiler = { module = "com.google.dagger:hilt-compiler", version.ref = "hilt" }
hilt-navigation-compose = { module = "androidx.hilt:hilt-navigation-compose", version.ref = "hilt-navigation-compose" }

retrofit = { module = "com.squareup.retrofit2:retrofit", version.ref = "retrofit" }
# Square's official kotlinx-serialization converter — shipped inside Retrofit 2.10+.
# Pin to the same `retrofit` ref. Do NOT use the older
# `com.jakewharton.retrofit:retrofit2-kotlinx-serialization-converter` artifact: it
# does not export the `asConverterFactory` symbol the templates rely on.
retrofit-kotlinx-serialization = { module = "com.squareup.retrofit2:converter-kotlinx-serialization", version.ref = "retrofit" }
okhttp = { module = "com.squareup.okhttp3:okhttp", version.ref = "okhttp" }
okhttp-logging = { module = "com.squareup.okhttp3:logging-interceptor", version.ref = "okhttp" }
kotlinx-serialization-json = { module = "org.jetbrains.kotlinx:kotlinx-serialization-json", version.ref = "kotlinx-serialization" }
# `kotlinx-coroutines-android` transitively brings `core`. Re-add an explicit
# `kotlinx-coroutines-core` entry only when extracting a `:core:domain` JVM module
# that needs it without the Android variant.
kotlinx-coroutines-android = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-android", version.ref = "coroutines" }

# Image loading — Coil 3 with Compose integration. The `coil-network-okhttp` artifact
# is required to fetch http(s) URLs; without it Coil 3 silently no-ops on network images.
coil-compose = { module = "io.coil-kt.coil3:coil-compose", version.ref = "coil" }
coil-network-okhttp = { module = "io.coil-kt.coil3:coil-network-okhttp", version.ref = "coil" }

# INCLUDE_ROOM
room-runtime = { module = "androidx.room:room-runtime", version.ref = "room" }
room-ktx = { module = "androidx.room:room-ktx", version.ref = "room" }
room-compiler = { module = "androidx.room:room-compiler", version.ref = "room" }

# INCLUDE_DATASTORE
datastore-preferences = { module = "androidx.datastore:datastore-preferences", version.ref = "datastore" }

# INCLUDE_FIREBASE — the *-ktx variants have been empty stubs since Firebase BOM 32.5.
# The KTX accessors moved into the main artifacts; use `com.google.firebase.Firebase`
# (no `.ktx` package) at call sites.
firebase-bom = { module = "com.google.firebase:firebase-bom", version.ref = "firebase-bom" }
firebase-crashlytics = { module = "com.google.firebase:firebase-crashlytics" }
firebase-analytics = { module = "com.google.firebase:firebase-analytics" }

junit = { module = "junit:junit", version.ref = "junit" }
androidx-test-ext-junit = { module = "androidx.test.ext:junit", version.ref = "androidx-test-ext-junit" }
mockk = { module = "io.mockk:mockk", version.ref = "mockk" }
turbine = { module = "app.cash.turbine:turbine", version.ref = "turbine" }
kotlinx-coroutines-test = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-test", version.ref = "coroutines-test" }

# Compose UI test artifacts come from the Compose BOM (no version.ref).
compose-ui-test-junit4 = { module = "androidx.compose.ui:ui-test-junit4" }
# `ui-test-manifest` lives in debugImplementation so the test app has the
# ComponentActivity manifest entry that createComposeRule()/createAndroidComposeRule() need.
compose-ui-test-manifest = { module = "androidx.compose.ui:ui-test-manifest" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
# `kotlin-android` is intentionally absent: AGP 9 has built-in Kotlin and registering
# the standalone plugin throws "Cannot add extension with name 'kotlin'". Re-add it
# (and the matching `alias(libs.plugins.kotlin.android)` in `app/build.gradle.kts`)
# only if you've intentionally pinned AGP 8.x.
kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
# Compose Compiler is its own Gradle plugin since Kotlin 2.0. The plugin alias must be
# applied on every module that sets `buildFeatures.compose = true` — the binary is
# bundled with Kotlin but the plugin is what actually wires it into the build.
kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
ksp = { id = "com.google.devtools.ksp", version.ref = "ksp" }
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
# INCLUDE_FIREBASE — version refs (not inline strings) so /upgrade-deps can surface
# them and the catalog stays consistent.
google-services = { id = "com.google.gms.google-services", version.ref = "google-services" }
firebase-crashlytics = { id = "com.google.firebase.crashlytics", version.ref = "firebase-crashlytics-plugin" }

# Re-add when extracting :core:* modules:
# android-library = { id = "com.android.library", version.ref = "agp" }
# kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
```

**Resolution rule: latest stable, every time.** Resolve each `[versions]` ref to the newest stable (no `-alpha`, `-beta`, `-RC`, `-dev`, `-SNAPSHOT`) by reading the registry's `maven-metadata.xml` at scaffold time. The command `/init-android-app` walks the catalog and fetches each one — see its **Phase 1.5** for the concrete URL list. Do not hard-code a number in this skill: hard-coded numbers age, and the user explicitly wants this command to work over time without churn.

**Compatibility traps (no fixed versions — describes the symptom + fix).** If the latest-stable resolution lands you in a known trap, the build fails in a recognizable way. Recognize it from the error and bump to whatever the relevant project's release notes call out as compatible.

| Trap | Symptom | Resolution |
|---|---|---|
| **Hilt vs current AGP** | `Cannot add extension with name 'kotlin'` / `Android BaseExtension not found` / `Could not find AGP base extension` at config time. | Hilt usually trails AGP majors by a few weeks. Use the latest Hilt; if it still fails, check the [Hilt release notes](https://github.com/google/dagger/releases) for the matching AGP support row and pin to that. |
| **KSP vs Kotlin alignment** | `error: KSP cannot be loaded` / weird annotation-processing failures. | KSP versioning is `<kotlinVersion>-<kspPatch>`. The Kotlin and KSP majors must agree (e.g. Kotlin 2.2.x ⇄ KSP 2.2.x-N.N.N). Resolve KSP only after Kotlin so you can build the right query. |
| **Compose BOM vs Material 3 surface** | `Unresolved reference: dynamicLightColorScheme` or similar Material 3 symbols. | The scaffold uses Material 3 APIs that arrived through 2024–2025 BOMs. Use the latest stable Compose BOM; old ones are missing surface. |
| **Retrofit converter coordinate** | `Unresolved reference: asConverterFactory`. | Retrofit 2.10+ ships Square's official `com.squareup.retrofit2:converter-kotlinx-serialization`, which is what the templates use. Older Retrofit forces the deprecated Jake Wharton converter, which doesn't export the same symbol. Use the latest Retrofit. |
| **Coroutines test API** | Test fails with `Module with the Main dispatcher had failed to initialize` / `Dispatchers.setMain` unresolved. | Need `kotlinx-coroutines-test` whose major matches `kotlinx-coroutines-core`. Resolve them off the same `coroutines` ref so they always agree. |
| **AGP 9 + KSP source dirs** | At config time: `Configuring Kotlin source sets is no longer supported. Please use the Android-specific source sets instead.` | Add `android.disallowKotlinSourceSets=false` to `gradle.properties` (already in the template). |
| **Compose Compiler plugin missing** | `Compose Compiler is required, but not applied` (or `composeCompiler extension not found`) on any module that sets `buildFeatures.compose = true`. | Since Kotlin 2.0 the Compose Compiler is its own Gradle plugin. The catalog ships it as `kotlin-compose` (version ref pinned to `kotlin`). Apply `alias(libs.plugins.kotlin.compose)` on every Compose-using module. Don't pin Compose Compiler separately — let the `kotlin` ref own it. |

If the resolved versions don't match this skill's idioms (e.g. the resolution lands AGP < 9 because the user pinned it), stop and surface the mismatch instead of silently downgrading.

> **Escape hatch: AGP 8.x.** The templates target AGP 9. To use AGP 8.x intentionally: (1) re-add `alias(libs.plugins.kotlin.android) apply false` at the root and `alias(libs.plugins.kotlin.android)` in `app/build.gradle.kts` (AGP 8 has no built-in Kotlin); (2) the `kotlin { compilerOptions { jvmTarget } }` block also works on AGP 8 with Kotlin 2.0+, so nothing to change there; (3) `android.disallowKotlinSourceSets=false` is unnecessary on AGP 8 (harmless to keep); (4) the `kotlin.compose` plugin alias is still required on Kotlin 2.0+ regardless of AGP major — leave it in.

---

## `:app` module

### `app/build.gradle.kts`

```kts
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    // No `kotlin.android` alias — AGP 9 has built-in Kotlin (see root build.gradle.kts).
    alias(libs.plugins.kotlin.serialization)
    // Required for `buildFeatures.compose = true` since Kotlin 2.0. Without this alias
    // the Kotlin compiler reports `Compose Compiler is required, but not applied`.
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
    // INCLUDE_FIREBASE: alias(libs.plugins.google.services)
    // INCLUDE_FIREBASE: alias(libs.plugins.firebase.crashlytics)
}

// Optional release signing — only wires up if `keystore.properties` exists.
// Commit `keystore.properties.example` (see post-scaffold notes); never commit the real one.
val keystoreProps = Properties().apply {
    val f = rootProject.file("keystore.properties")
    if (f.exists()) f.inputStream().use(::load)
}

android {
    namespace = "{{PACKAGE_ID}}"
    // Resolve at scaffold time to the latest stable platform SDK.
    compileSdk = {{COMPILE_SDK}}

    defaultConfig {
        applicationId = "{{PACKAGE_ID}}"
        minSdk = {{MIN_SDK}}
        targetSdk = {{TARGET_SDK}}
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables { useSupportLibrary = true }
        // FLAVORS_OFF: when productFlavors are not generated (Phase 0 Q8 = no), uncomment
        // the next line so BuildConfig.API_BASE_URL is still defined. With flavors on,
        // each flavor sets its own value below — leave this commented out.
        // buildConfigField("String", "API_BASE_URL", "\"{{API_BASE_URL_PROD}}\"")
    }

    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            // Retrofit requires a trailing slash. The runtime client reads BuildConfig.API_BASE_URL
            // (see core/data/network/di/NetworkModule.kt) — keep this the single source of truth.
            buildConfigField("String", "API_BASE_URL", "\"{{API_BASE_URL_DEV}}\"")
        }
        create("prod") {
            dimension = "env"
            buildConfigField("String", "API_BASE_URL", "\"{{API_BASE_URL_PROD}}\"")
        }
    }

    signingConfigs {
        if (keystoreProps.isNotEmpty()) {
            create("release") {
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
        }
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (keystoreProps.isNotEmpty()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
        compose = true
        buildConfig = true   // required by the DEBUG-gated Firebase collection toggle
    }
    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

// AGP 9 / Kotlin 2.2 — `kotlinOptions { jvmTarget = "17" }` was removed.
// Use the typed `compilerOptions` block at the root of the script.
kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

/* INCLUDE_FIREBASE: skip the google-services task per-variant when the matching
 * `google-services.json` hasn't been dropped yet — otherwise every Gradle sync /
 * `assembleDebug` / IDE reload fails before the user's first build. The plugin
 * runs normally as soon as a JSON exists for that flavor (or in src/main/). */
tasks.matching {
    it.name.startsWith("process") && it.name.endsWith("GoogleServices")
}.configureEach {
    // AGP names these `process<Flavor><BuildType>GoogleServices`, e.g. `processDevDebugGoogleServices`.
    val variant = name.removePrefix("process").removeSuffix("GoogleServices") // "DevDebug"
    val flavor = listOf("Debug", "Release")
        .firstNotNullOfOrNull { bt -> variant.removeSuffix(bt).takeIf { it != variant }?.lowercase() }
        ?: variant.lowercase()
    onlyIf {
        listOf("src/$flavor/google-services.json", "src/main/google-services.json")
            .any { project.file(it).exists() }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons.core)
    debugImplementation(libs.compose.tooling)
    implementation(libs.compose.tooling.preview)

    implementation(libs.navigation.compose)
    implementation(libs.kotlinx.serialization.json)

    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)

    // Networking
    implementation(libs.retrofit)
    implementation(libs.retrofit.kotlinx.serialization)
    implementation(libs.okhttp)
    implementation(libs.okhttp.logging)
    implementation(libs.kotlinx.coroutines.android)

    // Image loading (Coil 3). `coil-network-okhttp` is what lets `AsyncImage` fetch
    // http(s) URLs through the project's shared OkHttpClient (registered on the
    // Application via `SingletonImageLoader.Factory`).
    implementation(libs.coil.compose)
    implementation(libs.coil.network.okhttp)

    // INCLUDE_ROOM: implementation(libs.room.runtime)
    // INCLUDE_ROOM: implementation(libs.room.ktx)
    // INCLUDE_ROOM: ksp(libs.room.compiler)

    // INCLUDE_DATASTORE: implementation(libs.datastore.preferences)

    // INCLUDE_FIREBASE — no `-ktx` artifacts (deprecated since BOM 32.5).
    // INCLUDE_FIREBASE: implementation(platform(libs.firebase.bom))
    // INCLUDE_FIREBASE: implementation(libs.firebase.crashlytics)
    // INCLUDE_FIREBASE: implementation(libs.firebase.analytics)

    testImplementation(libs.junit)
    testImplementation(libs.mockk)
    testImplementation(libs.turbine)
    testImplementation(libs.kotlinx.coroutines.test)

    // Compose UI tests — pulled through the same Compose BOM so versions stay aligned.
    androidTestImplementation(platform(libs.compose.bom))
    androidTestImplementation(libs.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.ext.junit)
    debugImplementation(libs.compose.ui.test.manifest)
}
```

**Conditional dependency block markers.** Lines prefixed `// INCLUDE_<FLAG>:` are emitted verbatim (without the prefix) when the flag is true and dropped entirely when it's false. This is the same per-line shape used in the `plugins { ... }` block — the scaffolder strips `// INCLUDE_X: ` from each line that survives. Don't switch to multi-line section comments; the per-line marker is unambiguous and resilient to reordering.

**Placeholders to resolve at scaffold time:**

| Placeholder | Resolution |
|---|---|
| `{{COMPILE_SDK}}` | Latest stable platform SDK (resolve via the Android SDK manager metadata or hard-code the current cycle's value — do not pin to a stale integer). |
| `{{MIN_SDK}}` | Phase 0 answer (default 26; if INCLUDE_FIREBASE and the user wants dynamic color without a guard, propose 31). |
| `{{TARGET_SDK}}` | Same as `{{COMPILE_SDK}}` unless the user has a reason to lag. |

> **Optional: declarative compileSdk DSL.** AGP 8.10+ also supports `compileSdk { version = release(N) { minorApiLevel = 1 } }` for tracking minor platform updates. Stick with the integer form by default — it's simpler and the version catalog already gives you a single source of truth.

### `app/proguard-rules.pro`

Empty stub. AGP references this path from the `release` build type (`proguardFiles(getDefaultProguardFile(...), "proguard-rules.pro")`) and prints a warning if the file is missing — emitting an empty one keeps the build log clean. Most libraries used in this scaffold ship `consumer-rules.pro` so callers don't need to add anything: Compose, Hilt, Retrofit, OkHttp, kotlinx.serialization, Coil 3 — all self-keep. Add rules here only when R8 actually shrinks something it shouldn't (`./gradlew :app:bundleRelease` will surface a missing keep-rule as a runtime crash on a release `.aab`, never on a debug build).

```
# Project-specific ProGuard / R8 rules.
#
# Compose, Hilt, Retrofit, OkHttp, kotlinx-serialization, Coil 3 all ship
# consumer rules — leave this file empty until R8 strips something it shouldn't.
# When that happens, add the minimal `-keep` rule with a one-line comment
# explaining what was stripped and where the crash showed up.
```

### `app/src/main/AndroidManifest.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:name=".{{APP_CLASS}}"
        android:allowBackup="false"
        android:dataExtractionRules="@xml/data_extraction_rules"
        android:fullBackupContent="@xml/backup_rules"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:theme="@style/Theme.App">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:theme="@style/Theme.App">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### `app/src/main/res/values/strings.xml`

```xml
<resources>
    <string name="app_name">{{APP_DISPLAY_NAME}}</string>
    <string name="tab_feed">Feed</string>
    <string name="tab_profile">Profile</string>
</resources>
```

### `app/src/main/res/values/themes.xml`

The platform theme is the activity's window theme — the surface that paints **before** Compose has a chance to render. `DayNight.NoActionBar` honors the system dark/light mode, so a dark-mode device doesn't flash a light background on cold start. The Compose `AppTheme` (Material 3) takes over once `setContent` runs.

```xml
<resources xmlns:tools="http://schemas.android.com/tools">
    <style name="Theme.App" parent="android:Theme.DeviceDefault.DayNight.NoActionBar" />
</resources>
```

### `app/src/main/java/{{PACKAGE_PATH}}/{{APP_CLASS}}.kt`

Single variant for Firebase and non-Firebase scaffolds. The `AnalyticsTracker` interface is always present (`core/data/analytics/AnalyticsModule` binds it to `FirebaseAnalyticsTracker` or `NoopAnalyticsTracker` based on the `INCLUDE_FIREBASE` flag), so this Application class doesn't change shape.

The Application also implements `SingletonImageLoader.Factory` so Coil 3 reuses the project's single `OkHttpClient` (provided by `NetworkModule`) for image fetches — same connection pool, same interceptors (auth, headers) as Retrofit. Without this hook, `coil-network-okhttp` would silently fall back to its own internal network stack and any future `AuthInterceptor` wouldn't reach image requests.

`OkHttpClient` is injected as `Provider<OkHttpClient>` because `newImageLoader(...)` may be invoked before any composable triggers Hilt to materialize the singleton — `Provider.get()` defers construction until the first `AsyncImage` actually needs the client.

```kotlin
package {{PACKAGE_ID}}

import android.app.Application
import coil3.ImageLoader
import coil3.PlatformContext
import coil3.SingletonImageLoader
import coil3.network.okhttp.OkHttpNetworkFetcherFactory
import dagger.hilt.android.HiltAndroidApp
import okhttp3.OkHttpClient
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsTracker
import javax.inject.Inject
import javax.inject.Provider

@HiltAndroidApp
class {{APP_CLASS}} : Application(), SingletonImageLoader.Factory {
    @Inject lateinit var analytics: AnalyticsTracker
    @Inject lateinit var okHttpProvider: Provider<OkHttpClient>

    override fun onCreate() {
        super.onCreate()
        // No-op without Firebase. With Firebase: gates Crashlytics + Analytics
        // collection so debug installs don't pollute prod dashboards.
        analytics.setCollectionEnabled(!BuildConfig.DEBUG)
    }

    override fun newImageLoader(context: PlatformContext): ImageLoader =
        ImageLoader.Builder(context)
            .components {
                add(OkHttpNetworkFetcherFactory(callFactory = { okHttpProvider.get() }))
            }
            .build()
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/MainActivity.kt`

```kotlin
package {{PACKAGE_ID}}

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import {{PACKAGE_ID}}.core.navigation.AppNavGraph
import {{PACKAGE_ID}}.core.ui.theme.AppTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            AppTheme {
                AppNavGraph()
            }
        }
    }
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/core/ui/theme/AppTheme.kt`

Dynamic color is API 31+ only. Without the guard the app crashes at runtime on every device below Android 12 — roughly the bottom 10% of the install base. The fallback uses Material 3 baseline schemes; swap for a tonal palette of your brand colors when you have one.

```kotlin
package {{PACKAGE_ID}}.core.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val scheme = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val context = LocalContext.current
        if (dark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
    } else {
        if (dark) darkColorScheme() else lightColorScheme()
    }
    MaterialTheme(colorScheme = scheme, content = content)
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/core/navigation/AppNavGraph.kt`

Top-level nav has a single `Home` destination. The bottom-nav tabs are nested *inside* `HomeScreen` (its own `NavHost`), not flattened here — that keeps the bottom bar scoped to the Home graph and makes deep-link routing trivial when you add real auth/onboarding/settings destinations later.

```kotlin
package {{PACKAGE_ID}}.core.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import kotlinx.serialization.Serializable
import {{PACKAGE_ID}}.home.ui.HomeScreen

@Serializable data object Home

@Composable
fun AppNavGraph() {
    val nav = rememberNavController()
    NavHost(nav, startDestination = Home) {
        composable<Home> { HomeScreen() }
    }
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/home/ui/HomeViewModel.kt`

A minimal ViewModel that injects `AnalyticsTracker` privately and fires `AnalyticsEvent.HomeViewed` from `init { }`. This is the **one canonical pattern** for screen-viewed analytics in the scaffold — private dependency, event from `init { }`. `feed/ui/FeedViewModel.kt` and `profile/ui/ProfileViewModel.kt` follow the same shape; copy any of the three when adding a new screen.

```kotlin
package {{PACKAGE_ID}}.home.ui

import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsEvent
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsTracker
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val analytics: AnalyticsTracker,
) : ViewModel() {
    init {
        analytics.track(AnalyticsEvent.HomeViewed)
    }
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/home/ui/HomeScreen.kt`

Hosts the bottom `NavigationBar` and the *nested* tab `NavHost`. Tabs are typed `@Serializable` destinations. Selection is computed from the current back-stack entry via `NavDestination.hasRoute(KClass)` — no string comparisons, no hand-rolled selected-index state. The shell feature is the one place that knows about its tab features (`feed/`, `profile/`); tab features don't know about each other.

The `HomeViewed` analytics event fires from `HomeViewModel.init { }` — the same shape Feed and Profile use. `hiltViewModel()` is called here purely to construct the VM (and thereby fire the event) even though `HomeScreen` doesn't read any state from it.

```kotlin
package {{PACKAGE_ID}}.home.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import kotlinx.serialization.Serializable
import {{PACKAGE_ID}}.R
import {{PACKAGE_ID}}.feed.ui.FeedRoute
import {{PACKAGE_ID}}.profile.ui.ProfileRoute

@Serializable sealed interface HomeRoute {
    @Serializable data object Feed : HomeRoute
    @Serializable data object Profile : HomeRoute
}

private data class HomeTab(
    val route: HomeRoute,
    val labelRes: Int,
    val icon: ImageVector,
)

@Composable
fun HomeScreen(@Suppress("UNUSED_PARAMETER") viewModel: HomeViewModel = hiltViewModel()) {
    // The VM is constructed via hiltViewModel() so its init { } fires AnalyticsEvent.HomeViewed.
    val nav = rememberNavController()
    val backStack by nav.currentBackStackEntryAsState()
    val current = backStack?.destination

    val tabs = listOf(
        HomeTab(HomeRoute.Feed, R.string.tab_feed, Icons.Filled.Home),
        HomeTab(HomeRoute.Profile, R.string.tab_profile, Icons.Filled.Person),
    )

    Scaffold(
        bottomBar = {
            NavigationBar {
                tabs.forEach { tab ->
                    val label = stringResource(tab.labelRes)
                    NavigationBarItem(
                        selected = current?.hasRoute(tab.route::class) == true,
                        onClick = {
                            nav.navigate(tab.route) {
                                popUpTo(nav.graph.findStartDestination().id) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(tab.icon, contentDescription = label) },
                        label = { Text(label) },
                    )
                }
            }
        }
    ) { padding ->
        NavHost(
            navController = nav,
            startDestination = HomeRoute.Feed,
            modifier = Modifier.padding(padding),
        ) {
            composable<HomeRoute.Feed> { FeedRoute() }
            composable<HomeRoute.Profile> { ProfileRoute() }
        }
    }
}
```

### Feed feature

Feed ships the full feature-first shape — `data/` + `domain/` + `ui/`. Repository returns hard-coded stub data wrapped in `Outcome.Success`; replace with a real source when wiring a backend. The structure matches what `/new-feature` produces so adding the next feature is a copy-paste of this layout.

#### `app/src/main/java/{{PACKAGE_PATH}}/feed/domain/model/FeedItem.kt`

```kotlin
package {{PACKAGE_ID}}.feed.domain.model

data class FeedItem(
    val id: String,
    val title: String,
)
```

#### `app/src/main/java/{{PACKAGE_PATH}}/feed/domain/repository/FeedRepository.kt`

```kotlin
package {{PACKAGE_ID}}.feed.domain.repository

import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.feed.domain.model.FeedItem

interface FeedRepository {
    suspend fun getFeed(): Outcome<List<FeedItem>>
}
```

#### `app/src/main/java/{{PACKAGE_PATH}}/feed/domain/usecase/GetFeedUseCase.kt`

```kotlin
package {{PACKAGE_ID}}.feed.domain.usecase

import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.feed.domain.model.FeedItem
import {{PACKAGE_ID}}.feed.domain.repository.FeedRepository
import javax.inject.Inject

class GetFeedUseCase @Inject constructor(
    private val repository: FeedRepository,
) {
    suspend operator fun invoke(): Outcome<List<FeedItem>> = repository.getFeed()
}
```

#### `app/src/main/java/{{PACKAGE_PATH}}/feed/data/repository/FeedRepositoryImpl.kt`

```kotlin
package {{PACKAGE_ID}}.feed.data.repository

import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.feed.domain.model.FeedItem
import {{PACKAGE_ID}}.feed.domain.repository.FeedRepository
import javax.inject.Inject

class FeedRepositoryImpl @Inject constructor() : FeedRepository {
    // Stub data — replace with real source (Retrofit + RemoteDataSource or Room).
    override suspend fun getFeed(): Outcome<List<FeedItem>> = Outcome.Success(
        listOf(
            FeedItem(id = "1", title = "Welcome to your new app"),
            FeedItem(id = "2", title = "Edit FeedRepositoryImpl to wire a real source"),
            FeedItem(id = "3", title = "Tap retry to re-run the use case"),
        ),
    )
}
```

#### `app/src/main/java/{{PACKAGE_PATH}}/feed/data/di/FeedDataModule.kt`

```kotlin
package {{PACKAGE_ID}}.feed.data.di

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import {{PACKAGE_ID}}.feed.data.repository.FeedRepositoryImpl
import {{PACKAGE_ID}}.feed.domain.repository.FeedRepository

@Module
@InstallIn(SingletonComponent::class)
abstract class FeedDataModule {
    @Binds
    abstract fun bindFeedRepository(impl: FeedRepositoryImpl): FeedRepository
}
```

#### `app/src/main/java/{{PACKAGE_PATH}}/feed/ui/FeedUiState.kt`

```kotlin
package {{PACKAGE_ID}}.feed.ui

import {{PACKAGE_ID}}.feed.domain.model.FeedItem

sealed interface FeedUiState {
    data object Loading : FeedUiState
    data class Error(val message: String) : FeedUiState
    data class Success(val items: List<FeedItem>) : FeedUiState
}
```

#### `app/src/main/java/{{PACKAGE_PATH}}/feed/ui/FeedRoute.kt`

The typed `@Serializable` destination consumed by `AppNavGraph` / `HomeScreen`. Lives inside the feature's `ui/` package so the nav graph imports it from `feed.ui` — never from `core/navigation/`.

```kotlin
package {{PACKAGE_ID}}.feed.ui

import kotlinx.serialization.Serializable

@Serializable data object FeedRoute
```

#### `app/src/main/java/{{PACKAGE_PATH}}/feed/ui/FeedViewModel.kt`

Drives `Loading → Success/Error` from the use case, fires `AnalyticsEvent.FeedViewed` from `init { }` (canonical shape), exposes `retry()` as a discrete public function (no sealed `Action` — that's an MVI escalation, this project follows Google's Now in Android shape).

```kotlin
package {{PACKAGE_ID}}.feed.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsEvent
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsTracker
import {{PACKAGE_ID}}.feed.domain.usecase.GetFeedUseCase
import javax.inject.Inject

@HiltViewModel
class FeedViewModel @Inject constructor(
    private val getFeed: GetFeedUseCase,
    private val analytics: AnalyticsTracker,
) : ViewModel() {
    private val _state = MutableStateFlow<FeedUiState>(FeedUiState.Loading)
    val state: StateFlow<FeedUiState> = _state.asStateFlow()

    init {
        analytics.track(AnalyticsEvent.FeedViewed)
        load()
    }

    fun retry() {
        load()
    }

    private fun load() {
        _state.value = FeedUiState.Loading
        viewModelScope.launch {
            _state.value = when (val result = getFeed()) {
                is Outcome.Success -> FeedUiState.Success(result.value)
                is Outcome.Failure -> FeedUiState.Error(result.error::class.simpleName ?: "Unknown")
            }
        }
    }
}
```

#### `app/src/main/java/{{PACKAGE_PATH}}/feed/ui/FeedScreen.kt`

Route + Screen split — the project's canonical Compose shape (see `compose-ui`):

- **`FeedRoute`** (the `@Composable` wrapper) owns the ViewModel via `hiltViewModel()` and forwards state to the stateless screen. Lives in this file alongside `FeedScreen` so the route + UI sit together; the `@Serializable FeedRoute` destination is the data object in `FeedRoute.kt`.
- **`FeedScreen`** takes state + callbacks. Pure UI, previewable, testable without Hilt.
- **`@Preview`** renders the stateless screen with sample data per UiState branch.

```kotlin
package {{PACKAGE_ID}}.feed.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import {{PACKAGE_ID}}.core.ui.theme.AppTheme
import {{PACKAGE_ID}}.feed.domain.model.FeedItem

@Composable
fun FeedRoute(viewModel: FeedViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    FeedScreen(state = state, onRetry = viewModel::retry)
}

@Composable
fun FeedScreen(
    state: FeedUiState,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    when (state) {
        FeedUiState.Loading -> Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        is FeedUiState.Error -> Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Button(onClick = onRetry) {
                Text("Retry (${state.message})")
            }
        }
        is FeedUiState.Success -> LazyColumn(
            modifier = modifier.fillMaxSize().padding(8.dp),
        ) {
            items(state.items, key = { it.id }) { item ->
                ListItem(headlineContent = { Text(item.title) })
            }
        }
    }
}

@Preview
@Composable
private fun FeedScreenSuccessPreview() = AppTheme {
    FeedScreen(
        state = FeedUiState.Success(
            items = listOf(
                FeedItem("1", "Hello"),
                FeedItem("2", "World"),
            ),
        ),
        onRetry = {},
    )
}

@Preview
@Composable
private fun FeedScreenLoadingPreview() = AppTheme {
    FeedScreen(state = FeedUiState.Loading, onRetry = {})
}

@Preview
@Composable
private fun FeedScreenErrorPreview() = AppTheme {
    FeedScreen(state = FeedUiState.Error("Network"), onRetry = {})
}
```

### Profile feature

Profile mirrors Feed's three-layer shape. The repository returns a stub `ProfileInfo` wrapped in `Outcome.Success`; the screen renders the avatar via Coil's `AsyncImage` to demonstrate the end-to-end Coil wiring.

#### `app/src/main/java/{{PACKAGE_PATH}}/profile/domain/model/ProfileInfo.kt`

```kotlin
package {{PACKAGE_ID}}.profile.domain.model

data class ProfileInfo(
    val userName: String,
    val email: String,
    val avatarUrl: String?,
)
```

#### `app/src/main/java/{{PACKAGE_PATH}}/profile/domain/repository/ProfileRepository.kt`

```kotlin
package {{PACKAGE_ID}}.profile.domain.repository

import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.profile.domain.model.ProfileInfo

interface ProfileRepository {
    suspend fun getProfile(): Outcome<ProfileInfo>
}
```

#### `app/src/main/java/{{PACKAGE_PATH}}/profile/domain/usecase/GetProfileUseCase.kt`

```kotlin
package {{PACKAGE_ID}}.profile.domain.usecase

import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.profile.domain.model.ProfileInfo
import {{PACKAGE_ID}}.profile.domain.repository.ProfileRepository
import javax.inject.Inject

class GetProfileUseCase @Inject constructor(
    private val repository: ProfileRepository,
) {
    suspend operator fun invoke(): Outcome<ProfileInfo> = repository.getProfile()
}
```

#### `app/src/main/java/{{PACKAGE_PATH}}/profile/data/repository/ProfileRepositoryImpl.kt`

```kotlin
package {{PACKAGE_ID}}.profile.data.repository

import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.profile.domain.model.ProfileInfo
import {{PACKAGE_ID}}.profile.domain.repository.ProfileRepository
import javax.inject.Inject

class ProfileRepositoryImpl @Inject constructor() : ProfileRepository {
    // Stub data — replace with real source (Retrofit + RemoteDataSource or DataStore).
    override suspend fun getProfile(): Outcome<ProfileInfo> = Outcome.Success(
        ProfileInfo(
            userName = "guest",
            email = "guest@example.com",
            avatarUrl = null,
        ),
    )
}
```

#### `app/src/main/java/{{PACKAGE_PATH}}/profile/data/di/ProfileDataModule.kt`

```kotlin
package {{PACKAGE_ID}}.profile.data.di

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import {{PACKAGE_ID}}.profile.data.repository.ProfileRepositoryImpl
import {{PACKAGE_ID}}.profile.domain.repository.ProfileRepository

@Module
@InstallIn(SingletonComponent::class)
abstract class ProfileDataModule {
    @Binds
    abstract fun bindProfileRepository(impl: ProfileRepositoryImpl): ProfileRepository
}
```

#### `app/src/main/java/{{PACKAGE_PATH}}/profile/ui/ProfileUiState.kt`

```kotlin
package {{PACKAGE_ID}}.profile.ui

import {{PACKAGE_ID}}.profile.domain.model.ProfileInfo

sealed interface ProfileUiState {
    data object Loading : ProfileUiState
    data class Error(val message: String) : ProfileUiState
    data class Success(val profile: ProfileInfo) : ProfileUiState
}
```

#### `app/src/main/java/{{PACKAGE_PATH}}/profile/ui/ProfileRoute.kt`

```kotlin
package {{PACKAGE_ID}}.profile.ui

import kotlinx.serialization.Serializable

@Serializable data object ProfileRoute
```

#### `app/src/main/java/{{PACKAGE_PATH}}/profile/ui/ProfileViewModel.kt`

```kotlin
package {{PACKAGE_ID}}.profile.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsEvent
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsTracker
import {{PACKAGE_ID}}.profile.domain.usecase.GetProfileUseCase
import javax.inject.Inject

@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val getProfile: GetProfileUseCase,
    private val analytics: AnalyticsTracker,
) : ViewModel() {
    private val _state = MutableStateFlow<ProfileUiState>(ProfileUiState.Loading)
    val state: StateFlow<ProfileUiState> = _state.asStateFlow()

    init {
        analytics.track(AnalyticsEvent.ProfileViewed)
        load()
    }

    fun retry() {
        load()
    }

    private fun load() {
        _state.value = ProfileUiState.Loading
        viewModelScope.launch {
            _state.value = when (val result = getProfile()) {
                is Outcome.Success -> ProfileUiState.Success(result.value)
                is Outcome.Failure -> ProfileUiState.Error(result.error::class.simpleName ?: "Unknown")
            }
        }
    }
}
```

#### `app/src/main/java/{{PACKAGE_PATH}}/profile/ui/ProfileScreen.kt`

Same Route + Screen + Preview shape as Feed. The `AsyncImage` demonstrates Coil 3 end-to-end — `model = null` in the stub renders an empty placeholder, no network round-trip required. Coil's network fetcher reuses the project's `OkHttpClient` because `{{APP_CLASS}}` registered an `OkHttpNetworkFetcherFactory` (see "Application" above).

```kotlin
package {{PACKAGE_ID}}.profile.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import {{PACKAGE_ID}}.core.ui.theme.AppTheme
import {{PACKAGE_ID}}.profile.domain.model.ProfileInfo

@Composable
fun ProfileRoute(viewModel: ProfileViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    ProfileScreen(state = state, onRetry = viewModel::retry)
}

@Composable
fun ProfileScreen(
    state: ProfileUiState,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    when (state) {
        ProfileUiState.Loading -> Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        is ProfileUiState.Error -> Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Button(onClick = onRetry) {
                Text("Retry (${state.message})")
            }
        }
        is ProfileUiState.Success -> Column(
            modifier = modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            AsyncImage(
                model = state.profile.avatarUrl,
                contentDescription = null,
                modifier = Modifier
                    .size(96.dp)
                    .clip(CircleShape),
            )
            Text("Profile (${state.profile.userName})")
            Text(state.profile.email)
        }
    }
}

@Preview
@Composable
private fun ProfileScreenSuccessPreview() = AppTheme {
    ProfileScreen(
        state = ProfileUiState.Success(
            ProfileInfo(userName = "guest", email = "guest@example.com", avatarUrl = null),
        ),
        onRetry = {},
    )
}

@Preview
@Composable
private fun ProfileScreenLoadingPreview() = AppTheme {
    ProfileScreen(state = ProfileUiState.Loading, onRetry = {})
}

@Preview
@Composable
private fun ProfileScreenErrorPreview() = AppTheme {
    ProfileScreen(state = ProfileUiState.Error("Network"), onRetry = {})
}
```

### `app/src/test/java/{{PACKAGE_PATH}}/feed/ui/FeedViewModelTest.kt`

Plain JUnit 4 + MockK + Turbine — no Robolectric. Mocks the use case + tracker and verifies both `init { }` side effects: (a) `Loading → Success` transition driven by the use case, and (b) `AnalyticsEvent.FeedViewed` firing exactly once.

```kotlin
package {{PACKAGE_ID}}.feed.ui

import app.cash.turbine.test
import io.mockk.coEvery
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsEvent
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsTracker
import {{PACKAGE_ID}}.feed.domain.model.FeedItem
import {{PACKAGE_ID}}.feed.domain.usecase.GetFeedUseCase

class FeedViewModelTest {
    @Before fun setup() { Dispatchers.setMain(UnconfinedTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    @Test
    fun `emits Success after init`() = runTest {
        val getFeed = mockk<GetFeedUseCase>()
        coEvery { getFeed() } returns Outcome.Success(listOf(FeedItem("1", "hello")))
        val analytics = mockk<AnalyticsTracker>(relaxed = true)

        val vm = FeedViewModel(getFeed, analytics)
        vm.state.test {
            assertEquals(
                FeedUiState.Success(listOf(FeedItem("1", "hello"))),
                awaitItem(),
            )
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `tracks FeedViewed on init`() {
        val getFeed = mockk<GetFeedUseCase>()
        coEvery { getFeed() } returns Outcome.Success(emptyList())
        val analytics = mockk<AnalyticsTracker>(relaxed = true)

        FeedViewModel(getFeed, analytics)

        verify(exactly = 1) { analytics.track(AnalyticsEvent.FeedViewed) }
    }
}
```

### `app/src/test/java/{{PACKAGE_PATH}}/profile/ui/ProfileViewModelTest.kt`

```kotlin
package {{PACKAGE_ID}}.profile.ui

import app.cash.turbine.test
import io.mockk.coEvery
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsEvent
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsTracker
import {{PACKAGE_ID}}.profile.domain.model.ProfileInfo
import {{PACKAGE_ID}}.profile.domain.usecase.GetProfileUseCase

class ProfileViewModelTest {
    @Before fun setup() { Dispatchers.setMain(UnconfinedTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    @Test
    fun `emits Success after init`() = runTest {
        val info = ProfileInfo(userName = "guest", email = "g@e.com", avatarUrl = null)
        val getProfile = mockk<GetProfileUseCase>()
        coEvery { getProfile() } returns Outcome.Success(info)
        val analytics = mockk<AnalyticsTracker>(relaxed = true)

        val vm = ProfileViewModel(getProfile, analytics)
        vm.state.test {
            assertEquals(ProfileUiState.Success(info), awaitItem())
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `tracks ProfileViewed on init`() {
        val getProfile = mockk<GetProfileUseCase>()
        coEvery { getProfile() } returns Outcome.Success(
            ProfileInfo("guest", "g@e.com", null),
        )
        val analytics = mockk<AnalyticsTracker>(relaxed = true)

        ProfileViewModel(getProfile, analytics)

        verify(exactly = 1) { analytics.track(AnalyticsEvent.ProfileViewed) }
    }
}
```

### `app/src/androidTest/java/{{PACKAGE_PATH}}/feed/ui/FeedScreenTest.kt`

A happy-path Compose UI test that proves the Route/Screen split is testable without Hilt. The test drives the **stateless** `FeedScreen` directly — that's the whole point of hoisting state out of the composable. `compose-ui` and `/add-screen` both mandate this shape; the scaffold ships it so subsequent screens have a working template to copy.

```kotlin
package {{PACKAGE_ID}}.feed.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import org.junit.Rule
import org.junit.Test
import {{PACKAGE_ID}}.core.ui.theme.AppTheme
import {{PACKAGE_ID}}.feed.domain.model.FeedItem

class FeedScreenTest {
    @get:Rule val composeRule = createComposeRule()

    @Test fun rendersItems() {
        composeRule.setContent {
            AppTheme {
                FeedScreen(
                    state = FeedUiState.Success(
                        items = listOf(
                            FeedItem("1", "alpha"),
                            FeedItem("2", "beta"),
                        ),
                    ),
                    onRetry = {},
                )
            }
        }
        composeRule.onNodeWithText("alpha").assertIsDisplayed()
        composeRule.onNodeWithText("beta").assertIsDisplayed()
    }
}
```

### `app/src/androidTest/java/{{PACKAGE_PATH}}/profile/ui/ProfileScreenTest.kt`

```kotlin
package {{PACKAGE_ID}}.profile.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import org.junit.Rule
import org.junit.Test
import {{PACKAGE_ID}}.core.ui.theme.AppTheme
import {{PACKAGE_ID}}.profile.domain.model.ProfileInfo

class ProfileScreenTest {
    @get:Rule val composeRule = createComposeRule()

    @Test fun rendersUserName() {
        composeRule.setContent {
            AppTheme {
                ProfileScreen(
                    state = ProfileUiState.Success(
                        ProfileInfo(userName = "Ada", email = "ada@example.com", avatarUrl = null),
                    ),
                    onRetry = {},
                )
            }
        }
        composeRule.onNodeWithText("Profile (Ada)").assertIsDisplayed()
    }
}
```

---

## `core/domain/` package

Pure-Kotlin business logic. No `android.*` imports — keep these packages framework-free by convention so they stay unit-testable without Robolectric, and so extracting them to a `:core:domain` module later is mechanical.

### `app/src/main/java/{{PACKAGE_PATH}}/core/domain/Outcome.kt`

```kotlin
package {{PACKAGE_ID}}.core.domain

sealed interface Outcome<out T> {
    data class Success<T>(val value: T) : Outcome<T>
    data class Failure(val error: DomainError) : Outcome<Nothing>
}

inline fun <T, R> Outcome<T>.map(block: (T) -> R): Outcome<R> = when (this) {
    is Outcome.Success -> Outcome.Success(block(value))
    is Outcome.Failure -> this
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/core/domain/DomainError.kt`

```kotlin
package {{PACKAGE_ID}}.core.domain

sealed class DomainError(open val cause: Throwable? = null) {
    data class Network(override val cause: Throwable? = null) : DomainError(cause)
    data class Unauthorized(override val cause: Throwable? = null) : DomainError(cause)
    data class NotFound(override val cause: Throwable? = null) : DomainError(cause)
    data class Server(val code: Int, override val cause: Throwable? = null) : DomainError(cause)
    data class Unknown(override val cause: Throwable? = null) : DomainError(cause)
}
```

### `app/src/test/java/{{PACKAGE_PATH}}/core/domain/OutcomeMapTest.kt`

A 10-line test anchors the convention: `core/domain/` is plain Kotlin, framework-free, fast to test. Every new use case should have a sibling under `app/src/test/java/{{PACKAGE_PATH}}/<feature>/domain/`.

```kotlin
package {{PACKAGE_ID}}.core.domain

import org.junit.Assert.assertEquals
import org.junit.Test

class OutcomeMapTest {
    @Test
    fun `map transforms Success values`() {
        val result = Outcome.Success(2).map { it * 3 }
        assertEquals(Outcome.Success(6), result)
    }

    @Test
    fun `map propagates Failure unchanged`() {
        val original: Outcome<Int> = Outcome.Failure(DomainError.Network())
        assertEquals(original, original.map { it * 3 })
    }
}
```

### Analytics: `core/domain/analytics/`

The analytics interface is part of the **core/domain** layer so ViewModels and use cases depend on the abstraction, not on Firebase. The `core/data/` layer chooses the concrete implementation (Firebase or no-op) at wire-up time. This is the same pattern as repositories: the contract lives in `core/domain/`, the framework-bound code stays in `core/data/`. Without this split a `FeedViewModel` would import `com.google.firebase.*`, which leaks framework concerns into the layer that's supposed to be framework-free.

The event taxonomy is a sealed type, not a string. Magic strings sprinkled across screens are how analytics dashboards quietly drift; a sealed type forces every new event to land in one place that's grep-able and reviewable.

#### `app/src/main/java/{{PACKAGE_PATH}}/core/domain/analytics/AnalyticsTracker.kt`

```kotlin
package {{PACKAGE_ID}}.core.domain.analytics

interface AnalyticsTracker {
    fun track(event: AnalyticsEvent)
    fun setUserProperty(key: String, value: String?)
    /** Toggle collection at runtime (debug builds default off — see Application). */
    fun setCollectionEnabled(enabled: Boolean)
}
```

#### `app/src/main/java/{{PACKAGE_PATH}}/core/domain/analytics/AnalyticsEvent.kt`

```kotlin
package {{PACKAGE_ID}}.core.domain.analytics

/**
 * Add events here. The sealed type is the source of truth — implementations
 * route `name` + `params` to whatever backend is wired up (Firebase, Mixpanel, no-op).
 *
 * Keep names snake_case (Firebase + most backends prefer it) and parameters
 * primitive-only (String, Int, Long, Double, Boolean) — that's the intersection
 * of what every backend can serialize without a custom mapper.
 */
sealed class AnalyticsEvent(
    val name: String,
    val params: Map<String, Any?> = emptyMap(),
) {
    data object HomeViewed : AnalyticsEvent(name = "home_viewed")
    data object FeedViewed : AnalyticsEvent(name = "feed_viewed")
    data object ProfileViewed : AnalyticsEvent(name = "profile_viewed")

    data class ItemTapped(val itemId: String) : AnalyticsEvent(
        name = "item_tapped",
        params = mapOf("item_id" to itemId),
    )

    data class ScreenOpenedFromDeepLink(val route: String) : AnalyticsEvent(
        name = "deep_link_open",
        params = mapOf("route" to route),
    )
}
```

---

## `core/data/` package

Repository implementations + framework adapters (Retrofit, Room, DataStore). Depends on `core/domain/`; `core/domain/` never depends on it. All Retrofit / Room / DataStore deps already live in `app/build.gradle.kts` above — no separate module build file.

### `app/src/main/java/{{PACKAGE_PATH}}/core/data/network/SampleApi.kt`

Minimal Retrofit service + DTO so the scaffold demonstrates the full networking shape (interface + suspend fun + `@Serializable` DTO). Replace with real endpoints; the `ping` call is just an anchor.

```kotlin
package {{PACKAGE_ID}}.core.data.network

import kotlinx.serialization.Serializable
import retrofit2.http.GET

interface SampleApi {
    @GET("ping")
    suspend fun ping(): PingDto
}

@Serializable
data class PingDto(val ok: Boolean, val timestamp: Long)
```

### `app/src/main/java/{{PACKAGE_PATH}}/core/data/network/Outcomes.kt`

The **canonical adapter** between Kotlin's stdlib `Result<T>` and the project's `Outcome<T>`. Every repository / data-source that wants to lift `runCatching { ... }` into a domain `Outcome` goes through `toOutcome(...)`. Two reasons it has to live here, not get re-coded at each call site:

1. **`runCatching` swallows `CancellationException`** — open-coding `runCatching { ... }.fold(...)` silently breaks coroutine cancellation. `toOutcome` rethrows `CancellationException` so cancellation stays cooperative.
2. **One mapping table.** `toDomainError(...)` is the single place that translates `IOException` / `HttpException` codes into `DomainError`. Every new error category lands here once, not at every repository.

```kotlin
package {{PACKAGE_ID}}.core.data.network

import kotlinx.coroutines.CancellationException
import retrofit2.HttpException
import {{PACKAGE_ID}}.core.domain.DomainError
import {{PACKAGE_ID}}.core.domain.Outcome
import java.io.IOException

inline fun <T> Result<T>.toOutcome(mapError: (Throwable) -> DomainError): Outcome<T> =
    fold(
        onSuccess = { Outcome.Success(it) },
        onFailure = { t ->
            // CancellationException must propagate — runCatching swallows it.
            if (t is CancellationException) throw t
            Outcome.Failure(mapError(t))
        },
    )

fun toDomainError(t: Throwable): DomainError = when (t) {
    is IOException -> DomainError.Network(t)
    is HttpException -> when (val code = t.code()) {
        401 -> DomainError.Unauthorized(t)
        404 -> DomainError.NotFound(t)
        in 500..599 -> DomainError.Server(code, t)
        else -> DomainError.Unknown(t)
    }
    else -> DomainError.Unknown(t)
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/core/data/network/RemoteDataSource.kt`

Thin wrapper that maps Retrofit DTOs to `core/domain/` types. Repository implementations consume `RemoteDataSource`, never `SampleApi` directly. The exception-to-`DomainError` mapping lives in `Outcomes.kt` (one place); this class just lifts the call through `toOutcome`.

```kotlin
package {{PACKAGE_ID}}.core.data.network

import {{PACKAGE_ID}}.core.domain.Outcome
import javax.inject.Inject

class RemoteDataSource @Inject constructor(
    private val api: SampleApi,
) {
    suspend fun ping(): Outcome<Boolean> =
        runCatching { api.ping().ok }.toOutcome(::toDomainError)
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/core/data/network/di/NetworkModule.kt`

The single source of truth for the HTTP stack. Three reasons every piece is its own `@Provides`:

1. **`OkHttpClient` is shared.** Coil 3 reuses it for image fetching (see `{{APP_CLASS}}.newImageLoader`), and any future `AuthInterceptor` plugs in here once instead of in three places.
2. **Logging is gated on `BuildConfig.DEBUG`.** `Level.BODY` in release would log PII. `retrofit-networking` calls this out as a top pitfall.
3. **`Json` is its own singleton.** `provideRetrofit` takes it as a parameter so test modules can swap a stricter `Json` instance per test without rebuilding the whole stack.

```kotlin
package {{PACKAGE_ID}}.core.data.network.di

import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import retrofit2.create
import {{PACKAGE_ID}}.BuildConfig
import {{PACKAGE_ID}}.core.data.network.SampleApi
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides @Singleton
    fun provideOkHttp(): OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .apply {
            if (BuildConfig.DEBUG) {
                addInterceptor(
                    HttpLoggingInterceptor().apply { level = HttpLoggingInterceptor.Level.BODY },
                )
            }
        }
        .build()

    @Provides @Singleton
    fun provideJson(): Json = Json {
        ignoreUnknownKeys = true
        explicitNulls = false
        coerceInputValues = true
    }

    @Provides @Singleton
    fun provideRetrofit(client: OkHttpClient, json: Json): Retrofit = Retrofit.Builder()
        .baseUrl(BuildConfig.API_BASE_URL)
        .client(client)
        .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
        .build()

    @Provides @Singleton
    fun provideSampleApi(retrofit: Retrofit): SampleApi = retrofit.create()
}
```

`BuildConfig.API_BASE_URL` is wired per flavor in `app/build.gradle.kts` (`buildConfigField("String", "API_BASE_URL", ...)`). When flavors are off, the same field lives in `defaultConfig` instead — see the conditional in the build script template.

### Analytics: `core/data/analytics/`

The implementations of `AnalyticsTracker`. Two impls always exist; the Hilt module wires the right one based on `INCLUDE_FIREBASE`.

- `NoopAnalyticsTracker` — always emitted. Used when `INCLUDE_FIREBASE=false`, also handy in instrumentation tests so a real Firebase backend isn't required.
- `FirebaseAnalyticsTracker` — emitted only when `INCLUDE_FIREBASE=true`. Routes events through the Firebase SDK.

#### `app/src/main/java/{{PACKAGE_PATH}}/core/data/analytics/NoopAnalyticsTracker.kt` *(always emit)*

```kotlin
package {{PACKAGE_ID}}.core.data.analytics

import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsEvent
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsTracker
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NoopAnalyticsTracker @Inject constructor() : AnalyticsTracker {
    override fun track(event: AnalyticsEvent) = Unit
    override fun setUserProperty(key: String, value: String?) = Unit
    override fun setCollectionEnabled(enabled: Boolean) = Unit
}
```

#### `app/src/main/java/{{PACKAGE_PATH}}/core/data/analytics/FirebaseAnalyticsTracker.kt` *(INCLUDE_FIREBASE only)*

The mapping `AnalyticsEvent → Firebase logEvent` lives here, never in a ViewModel. If you ever switch backends (Mixpanel, Amplitude), only this file changes — domain + UI stay untouched. `paramsToBundle` deliberately handles only primitives: every analytics backend supports them and any caller passing something exotic deserves the compile-time push to flatten it.

**Critical: the impl is defensive against an uninitialized FirebaseApp.** The build-time `tasks.matching { processGoogleServices }.onlyIf { ... }` guard lets the project compile and install before `google-services.json` arrives — but `FirebaseInitProvider` only runs when the JSON is present, so `Firebase.analytics` would otherwise crash with `Default FirebaseApp is not initialized in this process` the first time the Application calls `setCollectionEnabled` on cold start. The `isFirebaseAvailable` check at every call site silently no-ops until the JSON is dropped in; once it is, the same impl starts emitting events without a code change.

```kotlin
package {{PACKAGE_ID}}.core.data.analytics

import android.content.Context
import android.os.Bundle
import com.google.firebase.Firebase
import com.google.firebase.FirebaseApp
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.analytics.analytics
import com.google.firebase.crashlytics.crashlytics
import dagger.hilt.android.qualifiers.ApplicationContext
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsEvent
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsTracker
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FirebaseAnalyticsTracker @Inject constructor(
    @ApplicationContext private val context: Context,
) : AnalyticsTracker {
    /** False until google-services.json lands and FirebaseInitProvider runs. */
    private val isFirebaseAvailable: Boolean
        get() = FirebaseApp.getApps(context).isNotEmpty()

    private val analytics: FirebaseAnalytics get() = Firebase.analytics

    override fun track(event: AnalyticsEvent) {
        if (!isFirebaseAvailable) return
        analytics.logEvent(event.name, event.params.toBundle())
    }

    override fun setUserProperty(key: String, value: String?) {
        if (!isFirebaseAvailable) return
        analytics.setUserProperty(key, value)
    }

    override fun setCollectionEnabled(enabled: Boolean) {
        if (!isFirebaseAvailable) return
        analytics.setAnalyticsCollectionEnabled(enabled)
        Firebase.crashlytics.isCrashlyticsCollectionEnabled = enabled
    }

    private fun Map<String, Any?>.toBundle(): Bundle = Bundle().also { b ->
        for ((k, v) in this) when (v) {
            null -> { /* skip — Firebase rejects null */ }
            is String -> b.putString(k, v)
            is Int -> b.putInt(k, v)
            is Long -> b.putLong(k, v)
            is Double -> b.putDouble(k, v)
            is Boolean -> b.putBoolean(k, v)
            else -> b.putString(k, v.toString())
        }
    }
}
```

#### `app/src/main/java/{{PACKAGE_PATH}}/core/data/analytics/AnalyticsModule.kt`

One `@Binds` chooses the impl. Without Firebase, the no-op is bound — every VM still works, just no events leave the device.

*Variant when `INCLUDE_FIREBASE=true`:*

```kotlin
package {{PACKAGE_ID}}.core.data.analytics

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsTracker

@Module
@InstallIn(SingletonComponent::class)
abstract class AnalyticsModule {
    @Binds
    abstract fun bindAnalyticsTracker(impl: FirebaseAnalyticsTracker): AnalyticsTracker
}
```

*Variant when `INCLUDE_FIREBASE=false`:*

```kotlin
package {{PACKAGE_ID}}.core.data.analytics

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsTracker

@Module
@InstallIn(SingletonComponent::class)
abstract class AnalyticsModule {
    @Binds
    abstract fun bindAnalyticsTracker(impl: NoopAnalyticsTracker): AnalyticsTracker
}
```

#### Canonical screen-viewed pattern

There is **one** screen-viewed pattern in this scaffold: inject `AnalyticsTracker` privately into the `ViewModel`, fire `AnalyticsEvent.<Screen>Viewed` from `init { }`. See `home/ui/HomeViewModel.kt`, `feed/ui/FeedViewModel.kt`, and `profile/ui/ProfileViewModel.kt` for the three reference implementations — they're identical in shape. No Compose helper, no `CompositionLocal`, no public VM dependency. Copy any of the three when adding a new screen.

---

## INCLUDE_ROOM additions

Only emit when `INCLUDE_ROOM` is true. The Room dependencies are already in `app/build.gradle.kts` above (under the `// INCLUDE_ROOM` block).

Persistence is shared infrastructure, so it lives under `core/data/persistence/`. Per-feature DAOs/entities can be promoted to `<feature>/data/persistence/` later if a feature owns its own table.

### `app/src/main/java/{{PACKAGE_PATH}}/core/data/persistence/AppDatabase.kt`

```kotlin
package {{PACKAGE_ID}}.core.data.persistence

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [SampleEntity::class],
    version = 1,
    exportSchema = true,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun sampleDao(): SampleDao
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/core/data/persistence/SampleEntity.kt`

```kotlin
package {{PACKAGE_ID}}.core.data.persistence

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "samples")
data class SampleEntity(
    @PrimaryKey val id: String,
    val label: String,
)
```

### `app/src/main/java/{{PACKAGE_PATH}}/core/data/persistence/SampleDao.kt`

```kotlin
package {{PACKAGE_ID}}.core.data.persistence

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface SampleDao {
    @Query("SELECT * FROM samples") fun observe(): Flow<List<SampleEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: SampleEntity)
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/core/data/persistence/di/PersistenceModule.kt`

The `@Module` that lets the rest of the graph `@Inject SampleDao` (or any future DAO) without knowing about the Room builder. Without this, the entity + DAO files compile but are unreachable from a ViewModel — the analytics flag's `AnalyticsModule` is the parallel, and `INCLUDE_ROOM` should ship the same level of wiring.

```kotlin
package {{PACKAGE_ID}}.core.data.persistence.di

import android.content.Context
import androidx.room.Room
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import {{PACKAGE_ID}}.core.data.persistence.AppDatabase
import {{PACKAGE_ID}}.core.data.persistence.SampleDao
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object PersistenceModule {
    @Provides @Singleton
    fun provideAppDatabase(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, "app.db").build()

    @Provides
    fun provideSampleDao(db: AppDatabase): SampleDao = db.sampleDao()
}
```

Enable schema export in `app/build.gradle.kts` (inside the `android { }` block):

```kts
ksp { arg("room.schemaLocation", "$projectDir/schemas") }
```

## INCLUDE_DATASTORE additions

### `app/src/main/java/{{PACKAGE_PATH}}/core/data/datastore/AppPreferences.kt`

`@Inject` + `@ApplicationContext` so this is reachable from any ViewModel / repository without manual construction. The `preferencesDataStore` delegate is registered as a top-level extension on `Context` exactly once — DataStore enforces a single instance per name per process and crashes with `Cannot have multiple DataStores active for the same file` if it's instantiated twice.

```kotlin
package {{PACKAGE_ID}}.core.data.datastore

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.prefs by preferencesDataStore(name = "app")

@Singleton
class AppPreferences @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val onboardingDone = booleanPreferencesKey("onboarding_done")

    fun onboardingDone(): Flow<Boolean> =
        context.prefs.data.map { it[onboardingDone] ?: false }

    suspend fun setOnboardingDone(done: Boolean) {
        context.prefs.edit { it[onboardingDone] = done }
    }
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/core/data/datastore/di/DataStoreModule.kt`

Mirrors the DI shape of `NetworkModule`, `PersistenceModule`, and `AnalyticsModule` — every feature-flagged piece of infrastructure ships its own Hilt module so the wiring is grep-able and uniform. `AppPreferences` is `@Inject`-constructable, but exposing it through a `@Provides @Singleton` here documents the singleton intent explicitly and gives test modules an obvious replacement seam.

```kotlin
package {{PACKAGE_ID}}.core.data.datastore.di

import android.content.Context
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import {{PACKAGE_ID}}.core.data.datastore.AppPreferences
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DataStoreModule {
    @Provides @Singleton
    fun provideAppPreferences(@ApplicationContext context: Context): AppPreferences =
        AppPreferences(context)
}
```

## INCLUDE_FIREBASE additions

Firebase auto-initializes via `FirebaseInitProvider` as soon as a `google-services.json` is present for the current flavor. The collection toggle in `Application.onCreate()` and the actual `logEvent` calls live in `core/data/analytics/FirebaseAnalyticsTracker` — see the **Analytics** section above. The Application class itself is the unified template (no Firebase-specific variant); it talks to `AnalyticsTracker` (the domain interface) which Hilt resolves to `FirebaseAnalyticsTracker` when this flag is on.

The Firebase artifacts in `app/build.gradle.kts` use `com.google.firebase:firebase-crashlytics` / `firebase-analytics` (no `-ktx` suffix) — the `*-ktx` variants have been empty stubs since Firebase BOM 32.5.

### Per-flavor `google-services.json`

Drop `google-services.json` into `app/src/dev/` and `app/src/prod/`. Never commit to `app/` root; the plugin will apply to every variant. The `tasks.matching` block in `app/build.gradle.kts` (above) makes the build skip the google-services task per-variant until the matching JSON is present, so `./gradlew :app:installDevDebug` works end-to-end on a freshly scaffolded project.

---

## Hard rules

- **Feature-first packaging.** Each feature is a top-level package containing only the layers it needs (`<feature>/{ui,domain,data}/`). Cross-feature plumbing lives under `core/`. Don't grow a global `ui/`, `domain/`, or `data/` next to features — that's the layer-first shape this scaffold deliberately avoids.
- **No `kapt`.** KSP only (Hilt 2.48+, Room 2.6+ all support KSP).
- **No string routes.** Navigation Compose 2.8+ typed destinations via `@Serializable` + `kotlinx-serialization` plugin.
- **Keep `core/domain/` and `<feature>/domain/` Android-free.** No `android.*` imports, no Compose, no Retrofit, no Room — only Kotlin stdlib + coroutines. Enforced by review until/unless you extract `:core:domain` / `:feature:<name>:domain` (a `kotlin.jvm` module would enforce it mechanically).
- **`ui/` consumes `domain/` interfaces, never `data/` types.** Repository implementations stay behind interfaces declared in `domain/`. Cross the boundary through use cases, not by reaching into `data/` directly.
- **One `Outcomes.kt` adapter, one `toDomainError(...)` mapper.** Every `runCatching { ... }` boundary call goes through `Result<T>.toOutcome(::toDomainError)`. Open-coding `runCatching { ... }.fold(...)` swallows `CancellationException` and silently breaks coroutine cancellation — see `core/data/network/Outcomes.kt` for the canonical implementation.
- **Compose BOM is the single source of truth** for Compose versions. Never pin individual Compose libs.
- **Apply `kotlin.compose` (the standalone Gradle plugin) on every module with `buildFeatures.compose = true`.** The plugin alias lives in the catalog as `kotlin-compose` and rides the `kotlin` version ref. Without the alias, the Kotlin compiler aborts with `Compose Compiler is required, but not applied`. Don't pin Compose Compiler separately.
- **Version catalog is the single source of truth** for all versions. Never inline `"2.1.0"` in a module `build.gradle.kts`.
- **Hilt on the Application**, on every `Activity` / `ViewModel` / Service that needs injection. Don't sprinkle `EntryPoint` unless you truly have a non-Hilt consumer.
- **`exportSchema = true`** is mandatory for Room once the app ships. The `schemas/` directory goes into version control.

## Signing-config inputs

The `app/build.gradle.kts` template above wires the release signing config to a root-level `keystore.properties` file. Commit a *redacted* `keystore.properties.example` so contributors know the shape; gitignore the real one.

### `keystore.properties.example`

```properties
# Copy to keystore.properties (gitignored) and fill in real values.
# Path is resolved relative to the repository root.
storeFile=release.keystore
storePassword=changeme
keyAlias=release
keyPassword=changeme
```

### `.gitignore` additions (root)

```
keystore.properties
*.keystore
/app/src/*/google-services.json
```

## Post-scaffold manual steps

Emit a block the command prints to the user:

```
Scaffold complete. Next steps:

☐ Generate a release keystore and copy keystore.properties.example → keystore.properties (gitignored).
   keytool -genkey -v -keystore release.keystore -alias release -keyalg RSA -keysize 2048 -validity 10000
   The signing config in app/build.gradle.kts auto-wires once keystore.properties exists.

☐ [if Firebase] drop google-services.json into app/src/dev/ and app/src/prod/.
   The build-time guard skips processGoogleServices per-variant until the JSON
   arrives, AND FirebaseAnalyticsTracker no-ops at runtime if FirebaseApp isn't
   initialized — so the project compiles, installs, AND launches from the moment
   you finish scaffolding. Events start flowing as soon as the JSON lands.

☐ [if Room] confirm app/schemas/ is populated after ./gradlew :app:kspDevDebugKotlin.
☐ Replace the Feed and Profile tab placeholders with your first real features
   (each tab is a typed `HomeRoute` destination under `ui/home/`).

Build and run:
  ./gradlew :app:installDevDebug
  ./gradlew :app:testDebugUnitTest
```
