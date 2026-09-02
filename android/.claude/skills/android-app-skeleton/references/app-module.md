# Reference — `:app` module + shell scaffolding

`app/build.gradle.kts`, `proguard-rules.pro`, manifest, strings, themes, the `{{APP_CLASS}}` Application, `MainActivity`, `core/ui/theme/AppTheme.kt`, `core/navigation/AppNavGraph.kt`, and the `home/ui/{HomeViewModel,HomeScreen}.kt` shell. Loaded at execution-order steps 3, 4, 7, and 8.

## `app/build.gradle.kts`

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

## `app/proguard-rules.pro`

Empty stub. AGP references this path from the `release` build type (`proguardFiles(getDefaultProguardFile(...), "proguard-rules.pro")`) and prints a warning if the file is missing — emitting an empty one keeps the build log clean. Most libraries used in this scaffold ship `consumer-rules.pro` so callers don't need to add anything: Compose, Hilt, Retrofit, OkHttp, kotlinx.serialization, Coil 3 — all self-keep. Add rules here only when R8 actually shrinks something it shouldn't (`./gradlew :app:bundleRelease` will surface a missing keep-rule as a runtime crash on a release `.aab`, never on a debug build).

```
# Project-specific ProGuard / R8 rules.
#
# Compose, Hilt, Retrofit, OkHttp, kotlinx-serialization, Coil 3 all ship
# consumer rules — leave this file empty until R8 strips something it shouldn't.
# When that happens, add the minimal `-keep` rule with a one-line comment
# explaining what was stripped and where the crash showed up.
```

## `app/src/main/AndroidManifest.xml`

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

## `app/src/main/res/values/strings.xml`

```xml
<resources>
    <string name="app_name">{{APP_DISPLAY_NAME}}</string>
    <string name="tab_feed">Feed</string>
    <string name="tab_profile">Profile</string>
</resources>
```

## `app/src/main/res/values/themes.xml`

The platform theme is the activity's window theme — the surface that paints **before** Compose has a chance to render. `DayNight.NoActionBar` honors the system dark/light mode, so a dark-mode device doesn't flash a light background on cold start. The Compose `AppTheme` (Material 3) takes over once `setContent` runs.

```xml
<resources xmlns:tools="http://schemas.android.com/tools">
    <style name="Theme.App" parent="android:Theme.DeviceDefault.DayNight.NoActionBar" />
</resources>
```

## `app/src/main/java/{{PACKAGE_PATH}}/{{APP_CLASS}}.kt`

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

## `app/src/main/java/{{PACKAGE_PATH}}/MainActivity.kt`

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

## `app/src/main/java/{{PACKAGE_PATH}}/core/ui/theme/AppTheme.kt`

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

## `app/src/main/java/{{PACKAGE_PATH}}/core/navigation/AppNavGraph.kt`

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

## `app/src/main/java/{{PACKAGE_PATH}}/home/ui/HomeViewModel.kt`

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

## `app/src/main/java/{{PACKAGE_PATH}}/home/ui/HomeScreen.kt`

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
