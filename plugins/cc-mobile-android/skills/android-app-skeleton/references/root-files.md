# Reference — Root files

Templates for the root of a fresh project: `settings.gradle.kts`, root `build.gradle.kts`, `gradle.properties`, `gradle/gradle-daemon-jvm.properties`, `gradle/libs.versions.toml`. Loaded at execution-order step 2.

## `settings.gradle.kts`

```kts
pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    // Required by gradle/gradle-daemon-jvm.properties — resolves the daemon JVM
    // toolchain via the Foojay Disco API so contributors don't need a specific JAVA_HOME.
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
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

## `build.gradle.kts` (root)

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

## `gradle.properties`

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

## `gradle/gradle-daemon-jvm.properties`

Pins the Gradle daemon JVM via the toolchain mechanism (foojay resolver). Preferred over relying on the user's `JAVA_HOME` — every contributor lands on the same JDK.

```properties
toolchainVersion=21
```

(JDK 21 runs the Gradle daemon; the project still targets bytecode 17 — see `compileOptions` and `kotlin { compilerOptions { jvmTarget } }` in `app/build.gradle.kts`.)

## `gradle/libs.versions.toml`

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

## Compatibility traps

If the latest-stable resolution lands you in a known trap, the build fails in a recognizable way. Recognize it from the error and bump to whatever the relevant project's release notes call out as compatible.

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
