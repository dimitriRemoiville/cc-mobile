# Reference — `core/data/` package

Repository implementations + framework adapters (Retrofit, Room, DataStore). Depends on `core/domain/`; `core/domain/` never depends on it. All Retrofit / Room / DataStore deps already live in `app/build.gradle.kts` — no separate module build file. Loaded at execution-order step 6.

## `app/src/main/java/{{PACKAGE_PATH}}/core/data/network/SampleApi.kt`

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

## `app/src/main/java/{{PACKAGE_PATH}}/core/data/network/Outcomes.kt`

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

## `app/src/main/java/{{PACKAGE_PATH}}/core/data/network/RemoteDataSource.kt`

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

## `app/src/main/java/{{PACKAGE_PATH}}/core/data/network/di/NetworkModule.kt`

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

## Analytics: `core/data/analytics/`

The implementations of `AnalyticsTracker`. Two impls always exist; the Hilt module wires the right one based on `INCLUDE_FIREBASE`.

- `NoopAnalyticsTracker` — always emitted. Used when `INCLUDE_FIREBASE=false`, also handy in instrumentation tests so a real Firebase backend isn't required.
- `FirebaseAnalyticsTracker` — emitted only when `INCLUDE_FIREBASE=true`. Routes events through the Firebase SDK.

### `app/src/main/java/{{PACKAGE_PATH}}/core/data/analytics/NoopAnalyticsTracker.kt` *(always emit)*

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

### `app/src/main/java/{{PACKAGE_PATH}}/core/data/analytics/FirebaseAnalyticsTracker.kt` *(INCLUDE_FIREBASE only)*

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

### `app/src/main/java/{{PACKAGE_PATH}}/core/data/analytics/AnalyticsModule.kt`

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

### Canonical screen-viewed pattern

There is **one** screen-viewed pattern in this scaffold: inject `AnalyticsTracker` privately into the `ViewModel`, fire `AnalyticsEvent.<Screen>Viewed` from `init { }`. See `home/ui/HomeViewModel.kt`, `feed/ui/FeedViewModel.kt`, and `profile/ui/ProfileViewModel.kt` for the three reference implementations — they're identical in shape. No Compose helper, no `CompositionLocal`, no public VM dependency. Copy any of the three when adding a new screen.
