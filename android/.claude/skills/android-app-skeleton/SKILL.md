---
name: android-app-skeleton
description: Authoritative blueprint for scaffolding a brand-new Android app with this project's conventions. Used by /init-android-app. Contains every file template, placeholder list, feature-flag block, and the procedure to emit a runnable splash.
---

# Android app skeleton

This file is the template registry. The `/init-android-app` command reads this skill top-to-bottom and substitutes placeholders before writing files. Do not improvise: the whole point of the skeleton is reproducibility.

## Placeholders

| Placeholder | Meaning | Example |
|---|---|---|
| `{{APP_NAME}}` | Gradle project folder name, lowercase kebab or snake | `my_app` |
| `{{APP_CLASS}}` | `Application` subclass name in PascalCase | `MyApp` |
| `{{PACKAGE_ID}}` | applicationId / root package | `com.example.myapp` |
| `{{PACKAGE_PATH}}` | slash form of package id | `com/example/myapp` |
| `{{APP_DISPLAY_NAME}}` | Human-facing name | `My App` |

## Feature flags

| Flag | Adds |
|---|---|
| `INCLUDE_ROOM` | Room module + entities/DAO/DB, migration skeleton, schema export |
| `INCLUDE_DATASTORE` | DataStore module + typed prefs |
| `INCLUDE_FIREBASE` | google-services plugin + Crashlytics + Analytics init |

## Layout

Single Gradle module, `:app`. Clean Architecture layers live as packages under `app/src/main/java/{{PACKAGE_PATH}}/`:

```
ui/        → Compose + ViewModels (knows Android & Compose)
  ↓
domain/    → Pure-Kotlin business logic (no android.* imports, by convention)
  ↑
data/      → Repository impls, Retrofit, Room, DataStore (knows frameworks)
```

Why not start multi-module? The module tax (extra build.gradle.kts per module, explicit `project(":core:*")` wiring, slower first build) rarely pays off before you have real coupling pressure — a second app, a shared library, or a team boundary. Extracting `:core:domain` / `:core:data` later is mechanical once the pain is real. See `clean-architecture/SKILL.md` → "Module or package?".

## Execution order

1. Create directory `{{APP_NAME}}/` with Gradle wrapper.
2. Write `settings.gradle.kts`, root `build.gradle.kts`, `gradle.properties`, `gradle/libs.versions.toml`.
3. Write `app/build.gradle.kts` (single module — it carries all runtime deps).
4. Write `AndroidManifest.xml`, `strings.xml`, themes, launcher icons.
5. Write `domain/` package (Outcome, DomainError, sample use case contract).
6. Write `data/` package (Retrofit/OkHttp factory, Hilt module). Add `data/persistence/` + `data/datastore/` behind flags.
7. Write UI (`{{APP_CLASS}}` Application, `MainActivity`, theme, splash screen + VM, nav graph).
8. Write `:app` tests (splash VM test under `app/src/test/`).
9. Compile + run unit tests.
10. Emit manual setup notes (signing, flavor stubs, Firebase files).

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
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.ksp) apply false
    alias(libs.plugins.hilt) apply false
    // INCLUDE_FIREBASE: alias(libs.plugins.google.services) apply false
    // INCLUDE_FIREBASE: alias(libs.plugins.firebase.crashlytics) apply false
}
```

`android.library` and `kotlin.jvm` plugin aliases are intentionally omitted — there are no library / pure-JVM modules yet. Add them to `libs.versions.toml` and this block when you extract `:core:*` modules.

### `gradle.properties`

```properties
org.gradle.jvmargs=-Xmx4g -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.configuration-cache=true
kotlin.code.style=official
android.useAndroidX=true
android.nonTransitiveRClass=true
```

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
retrofit = "<latest-stable>"
retrofit-kotlinx-serialization = "<latest-stable>"
okhttp = "<latest-stable>"
kotlinx-serialization = "<latest-stable>"
datastore = "<latest-stable>"
room = "<latest-stable>"
firebase-bom = "<latest-stable>"
junit = "<latest-stable>"
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
compose-tooling = { module = "androidx.compose.ui:ui-tooling" }
compose-tooling-preview = { module = "androidx.compose.ui:ui-tooling-preview" }

navigation-compose = { module = "androidx.navigation:navigation-compose", version.ref = "navigation-compose" }

hilt-android = { module = "com.google.dagger:hilt-android", version.ref = "hilt" }
hilt-compiler = { module = "com.google.dagger:hilt-compiler", version.ref = "hilt" }
hilt-navigation-compose = { module = "androidx.hilt:hilt-navigation-compose", version.ref = "hilt-navigation-compose" }

retrofit = { module = "com.squareup.retrofit2:retrofit", version.ref = "retrofit" }
retrofit-kotlinx-serialization = { module = "com.jakewharton.retrofit:retrofit2-kotlinx-serialization-converter", version.ref = "retrofit-kotlinx-serialization" }
okhttp = { module = "com.squareup.okhttp3:okhttp", version.ref = "okhttp" }
okhttp-logging = { module = "com.squareup.okhttp3:logging-interceptor", version.ref = "okhttp" }
kotlinx-serialization-json = { module = "org.jetbrains.kotlinx:kotlinx-serialization-json", version.ref = "kotlinx-serialization" }
kotlinx-coroutines-core = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-core", version.ref = "coroutines" }
kotlinx-coroutines-android = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-android", version.ref = "coroutines" }

# INCLUDE_ROOM
room-runtime = { module = "androidx.room:room-runtime", version.ref = "room" }
room-ktx = { module = "androidx.room:room-ktx", version.ref = "room" }
room-compiler = { module = "androidx.room:room-compiler", version.ref = "room" }

# INCLUDE_DATASTORE
datastore-preferences = { module = "androidx.datastore:datastore-preferences", version.ref = "datastore" }

# INCLUDE_FIREBASE
firebase-bom = { module = "com.google.firebase:firebase-bom", version.ref = "firebase-bom" }
firebase-crashlytics = { module = "com.google.firebase:firebase-crashlytics-ktx" }
firebase-analytics = { module = "com.google.firebase:firebase-analytics-ktx" }

junit = { module = "junit:junit", version.ref = "junit" }
mockk = { module = "io.mockk:mockk", version.ref = "mockk" }
turbine = { module = "app.cash.turbine:turbine", version.ref = "turbine" }
kotlinx-coroutines-test = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-test", version.ref = "coroutines-test" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
android-library = { id = "com.android.library", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
ksp = { id = "com.google.devtools.ksp", version.ref = "ksp" }
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
# INCLUDE_FIREBASE
google-services = { id = "com.google.gms.google-services", version = "<latest-stable>" }
firebase-crashlytics = { id = "com.google.firebase.crashlytics", version = "<latest-stable>" }
```

**Floor constraints (enforce before writing the file):**

| Ref | Floor | Reason |
|---|---|---|
| `agp` | `>= 8.5.0` | K2 Kotlin plugin + Compose Compiler Gradle plugin both need AGP 8.5+. |
| `kotlin` | `>= 2.0.0` | K2 compiler + the `org.jetbrains.kotlin.plugin.compose` plugin; the rest of the skill assumes K2 diagnostics. |
| `ksp` | matches `kotlin` patch version (e.g. `2.0.21-1.0.28`) | KSP versioning is `<kotlinVersion>-<kspPatch>`; misalignment is the #1 cause of broken annotation processing. |
| `hilt` | `>= 2.51` | First version with official KSP support — the skill uses `ksp(libs.hilt.compiler)`, not kapt. |
| `compose-bom` | `>= 2024.09.00` | Material 3 APIs the scaffold uses assume late-2024 BOM. |
| `room` | `>= 2.6.0` | KSP support; the skill uses `ksp(libs.room.compiler)`. |
| `coroutines` | `>= 1.8.0` | `Dispatchers.setMain` in tests + structured cancellation guarantees the skill relies on. |
| `activity-compose` | `>= 1.9.0` | Predictive-back integration. |

If any resolved version falls below its floor, stop and report. Don't silently downgrade the template.

---

## `:app` module

### `app/build.gradle.kts`

```kts
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
    // INCLUDE_FIREBASE: alias(libs.plugins.google.services)
    // INCLUDE_FIREBASE: alias(libs.plugins.firebase.crashlytics)
}

android {
    namespace = "{{PACKAGE_ID}}"
    compileSdk = 35

    defaultConfig {
        applicationId = "{{PACKAGE_ID}}"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables { useSupportLibrary = true }
    }

    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
        create("prod") {
            dimension = "env"
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
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
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

    // INCLUDE_ROOM
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)

    // INCLUDE_DATASTORE
    implementation(libs.datastore.preferences)

    // INCLUDE_FIREBASE
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.crashlytics)
    implementation(libs.firebase.analytics)

    testImplementation(libs.junit)
    testImplementation(libs.mockk)
    testImplementation(libs.turbine)
    testImplementation(libs.kotlinx.coroutines.test)
}
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
</resources>
```

### `app/src/main/res/values/themes.xml`

```xml
<resources xmlns:tools="http://schemas.android.com/tools">
    <style name="Theme.App" parent="android:Theme.Material.Light.NoActionBar" />
</resources>
```

### `app/src/main/java/{{PACKAGE_PATH}}/{{APP_CLASS}}.kt`

```kotlin
package {{PACKAGE_ID}}

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class {{APP_CLASS}} : Application()
```

### `app/src/main/java/{{PACKAGE_PATH}}/MainActivity.kt`

```kotlin
package {{PACKAGE_ID}}

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import {{PACKAGE_ID}}.navigation.AppNavGraph
import {{PACKAGE_ID}}.ui.theme.AppTheme
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

### `app/src/main/java/{{PACKAGE_PATH}}/ui/theme/AppTheme.kt`

```kotlin
package {{PACKAGE_ID}}.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.isSystemInDarkTheme

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    val context = LocalContext.current
    val scheme = if (isSystemInDarkTheme()) dynamicDarkColorScheme(context)
    else dynamicLightColorScheme(context)
    MaterialTheme(colorScheme = scheme, content = content)
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/navigation/AppNavGraph.kt`

```kotlin
package {{PACKAGE_ID}}.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import kotlinx.serialization.Serializable
import {{PACKAGE_ID}}.ui.splash.SplashScreen

@Serializable data object Splash

@Composable
fun AppNavGraph() {
    val nav = rememberNavController()
    NavHost(nav, startDestination = Splash) {
        composable<Splash> { SplashScreen() }
    }
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/ui/splash/SplashScreen.kt`

```kotlin
package {{PACKAGE_ID}}.ui.splash

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@Composable
fun SplashScreen(vm: SplashViewModel = hiltViewModel()) {
    val state by vm.state.collectAsStateWithLifecycle()
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(state.message)
    }
}

@Preview
@Composable
private fun SplashPreview() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text("{{APP_DISPLAY_NAME}}")
    }
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/ui/splash/SplashViewModel.kt`

```kotlin
package {{PACKAGE_ID}}.ui.splash

import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject

data class SplashState(val message: String = "{{APP_DISPLAY_NAME}}")

@HiltViewModel
class SplashViewModel @Inject constructor() : ViewModel() {
    private val _state = MutableStateFlow(SplashState())
    val state: StateFlow<SplashState> = _state.asStateFlow()
}
```

### `app/src/test/java/{{PACKAGE_PATH}}/ui/splash/SplashViewModelTest.kt`

```kotlin
package {{PACKAGE_ID}}.ui.splash

import app.cash.turbine.test
import org.junit.Test
import kotlin.test.assertEquals

class SplashViewModelTest {
    @Test
    fun `emits initial state with app display name`() = kotlinx.coroutines.test.runTest {
        val vm = SplashViewModel()
        vm.state.test {
            assertEquals("{{APP_DISPLAY_NAME}}", awaitItem().message)
            cancelAndIgnoreRemainingEvents()
        }
    }
}
```

---

## `domain/` package

Pure-Kotlin business logic. No `android.*` imports — keep this package framework-free by convention so it stays unit-testable without Robolectric, and so extracting it to a `:core:domain` module later is mechanical.

### `app/src/main/java/{{PACKAGE_PATH}}/domain/Outcome.kt`

```kotlin
package {{PACKAGE_ID}}.domain

sealed interface Outcome<out T> {
    data class Success<T>(val value: T) : Outcome<T>
    data class Failure(val error: DomainError) : Outcome<Nothing>
}

inline fun <T, R> Outcome<T>.map(block: (T) -> R): Outcome<R> = when (this) {
    is Outcome.Success -> Outcome.Success(block(value))
    is Outcome.Failure -> this
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/domain/DomainError.kt`

```kotlin
package {{PACKAGE_ID}}.domain

sealed class DomainError(open val cause: Throwable? = null) {
    data class Network(override val cause: Throwable? = null) : DomainError(cause)
    data class Unauthorized(override val cause: Throwable? = null) : DomainError(cause)
    data class NotFound(override val cause: Throwable? = null) : DomainError(cause)
    data class Server(val code: Int, override val cause: Throwable? = null) : DomainError(cause)
    data class Unknown(override val cause: Throwable? = null) : DomainError(cause)
}
```

---

## `data/` package

Repository implementations + framework adapters (Retrofit, Room, DataStore). Depends on `domain/`; `domain/` never depends on it. All Retrofit / Room / DataStore deps already live in `app/build.gradle.kts` above — no separate module build file.

### `app/src/main/java/{{PACKAGE_PATH}}/data/network/ApiClientFactory.kt`

```kotlin
package {{PACKAGE_ID}}.data.network

import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import java.util.concurrent.TimeUnit

object ApiClientFactory {
    fun retrofit(baseUrl: String): Retrofit {
        val client = OkHttpClient.Builder()
            .callTimeout(30, TimeUnit.SECONDS)
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .addInterceptor(HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BASIC
            })
            .build()

        val json = Json { ignoreUnknownKeys = true; explicitNulls = false }
        return Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()
    }
}
```

### `app/src/main/java/{{PACKAGE_PATH}}/data/di/DataModule.kt`

```kotlin
package {{PACKAGE_ID}}.data.di

import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import retrofit2.Retrofit
import {{PACKAGE_ID}}.data.network.ApiClientFactory
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DataModule {
    @Provides @Singleton
    fun retrofit(): Retrofit = ApiClientFactory.retrofit("https://example.invalid/")
}
```

---

## INCLUDE_ROOM additions

Only emit when `INCLUDE_ROOM` is true. The Room dependencies are already in `app/build.gradle.kts` above (under the `// INCLUDE_ROOM` block).

### `app/src/main/java/{{PACKAGE_PATH}}/data/persistence/AppDatabase.kt`

```kotlin
package {{PACKAGE_ID}}.data.persistence

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

### `app/src/main/java/{{PACKAGE_PATH}}/data/persistence/SampleEntity.kt`

```kotlin
package {{PACKAGE_ID}}.data.persistence

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "samples")
data class SampleEntity(
    @PrimaryKey val id: String,
    val label: String,
)
```

### `app/src/main/java/{{PACKAGE_PATH}}/data/persistence/SampleDao.kt`

```kotlin
package {{PACKAGE_ID}}.data.persistence

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

Enable schema export in `app/build.gradle.kts` (inside the `android { }` block):

```kts
ksp { arg("room.schemaLocation", "$projectDir/schemas") }
```

## INCLUDE_DATASTORE additions

### `app/src/main/java/{{PACKAGE_PATH}}/data/datastore/AppPreferences.kt`

```kotlin
package {{PACKAGE_ID}}.data.datastore

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.prefs by preferencesDataStore(name = "app")

class AppPreferences(private val context: Context) {
    private val onboardingDone = booleanPreferencesKey("onboarding_done")

    fun onboardingDone(): Flow<Boolean> =
        context.prefs.data.map { it[onboardingDone] ?: false }

    suspend fun setOnboardingDone(done: Boolean) {
        context.prefs.edit { it[onboardingDone] = done }
    }
}
```

## INCLUDE_FIREBASE additions

In `{{APP_CLASS}}.onCreate` (no direct Firebase API calls at this layer — keep behind an interface; just ensure init + the plugin):

```kotlin
override fun onCreate() {
    super.onCreate()
    // google-services plugin initializes Firebase automatically when a
    // google-services.json is present for the current flavor.
    // Crashlytics collection is controlled via manifest meta-data or runtime setCrashlyticsCollectionEnabled().
}
```

Per-flavor file layout reminder: drop `google-services.json` into `app/src/dev/` and `app/src/prod/`. Never commit to `app/` root; the plugin will then apply to every variant.

---

## Hard rules

- **No `kapt`.** KSP only (Hilt 2.48+, Room 2.6+ all support KSP).
- **No string routes.** Navigation Compose 2.8+ typed destinations via `@Serializable` + `kotlinx-serialization` plugin.
- **Keep the `domain/` package Android-free.** No `android.*` imports, no Compose, no Retrofit, no Room — only Kotlin stdlib + coroutines. Enforced by review until/unless you extract `:core:domain` (a `kotlin.jvm` module would enforce it mechanically).
- **`ui/` consumes `domain/` interfaces, never `data/` types.** Repository implementations stay behind interfaces declared in `domain/`. Cross the boundary through use cases, not by reaching into `data/` directly.
- **Compose BOM is the single source of truth** for Compose versions. Never pin individual Compose libs.
- **Version catalog is the single source of truth** for all versions. Never inline `"2.1.0"` in a module `build.gradle.kts`.
- **Hilt on the Application**, on every `Activity` / `ViewModel` / Service that needs injection. Don't sprinkle `EntryPoint` unless you truly have a non-Hilt consumer.
- **`exportSchema = true`** is mandatory for Room once the app ships. The `schemas/` directory goes into version control.

## Post-scaffold manual steps

Emit a block the command prints to the user:

```
Scaffold complete. Next steps:

☐ Add release signing config in app/build.gradle.kts:
    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("SIGNING_KEYSTORE") ?: "release.keystore")
            storePassword = System.getenv("SIGNING_STORE_PASSWORD")
            keyAlias = System.getenv("SIGNING_KEY_ALIAS")
            keyPassword = System.getenv("SIGNING_KEY_PASSWORD")
        }
    }

☐ [if Firebase] drop google-services.json into app/src/dev/ and app/src/prod/.
☐ [if Firebase] confirm ./gradlew :app:processDevDebugGoogleServices runs without error.
☐ [if Room] confirm app/schemas/ is populated after ./gradlew :app:kspDevDebugKotlin.
☐ Replace the splash screen placeholder with the first real feature.

Build and run:
  ./gradlew :app:installDevDebug
  ./gradlew :app:testDebugUnitTest
```
