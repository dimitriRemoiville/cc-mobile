# Reference — INCLUDE_DATASTORE additions

Only emit when `INCLUDE_DATASTORE` is true. The DataStore dependency is already in `app/build.gradle.kts` (under the `// INCLUDE_DATASTORE` line in [app-module.md](app-module.md)).

## `app/src/main/java/{{PACKAGE_PATH}}/core/data/datastore/AppPreferences.kt`

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

## `app/src/main/java/{{PACKAGE_PATH}}/core/data/datastore/di/DataStoreModule.kt`

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
