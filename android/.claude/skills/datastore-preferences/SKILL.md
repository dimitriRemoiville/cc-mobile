---
name: datastore-preferences
description: DataStore patterns for this Android project — Preferences DataStore for key/value, Proto DataStore for structured state, migrating off SharedPreferences, scoping, and multi-process gotchas. Load whenever adding a new setting or on-device preference.
---

# DataStore

## Which variant

- **Preferences DataStore** — free-form typed keys (`stringPreferencesKey`, `booleanPreferencesKey`). Use for a handful of independent toggles and scalars.
- **Proto DataStore** — a single protobuf (or `kotlinx.serialization`) message as the whole store. Use when values are related (onboarding state, feature config, filters), or when type-safety across keys matters.

If you would write more than ~10 keys in a Preferences store, you want Proto.

## Single top-level instance

Never construct a `DataStore` ad hoc. One instance per file, injected via Hilt.

```kotlin
private val Context.settingsDataStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

@Module
@InstallIn(SingletonComponent::class)
object DataStoreModule {
    @Provides @Singleton
    fun provideSettings(@ApplicationContext ctx: Context): DataStore<Preferences> = ctx.settingsDataStore
}
```

For Proto:

```kotlin
private val Context.userStateStore: DataStore<UserState> by dataStore(
    fileName = "user_state.pb",
    serializer = UserStateSerializer,
)

object UserStateSerializer : Serializer<UserState> {
    override val defaultValue: UserState = UserState.DEFAULT
    override suspend fun readFrom(input: InputStream): UserState =
        try { Json.decodeFromStream(input) } catch (e: SerializationException) { throw CorruptionException("bad", e) }
    override suspend fun writeTo(t: UserState, output: OutputStream) =
        withContext(Dispatchers.IO) { Json.encodeToStream(t, output) }
}
```

## Repository wrapping

Presentation never touches `DataStore` directly. Wrap it in a settings repository:

```kotlin
interface SettingsRepository {
    val theme: Flow<AppTheme>
    suspend fun setTheme(theme: AppTheme)
}

class SettingsRepositoryImpl @Inject constructor(
    private val store: DataStore<Preferences>,
) : SettingsRepository {
    private object Keys { val THEME = stringPreferencesKey("theme") }

    override val theme: Flow<AppTheme> = store.data
        .catch { e -> if (e is IOException) emit(emptyPreferences()) else throw e }
        .map { prefs -> AppTheme.valueOf(prefs[Keys.THEME] ?: AppTheme.SYSTEM.name) }
        .distinctUntilChanged()

    override suspend fun setTheme(theme: AppTheme) {
        store.edit { it[Keys.THEME] = theme.name }
    }
}
```

Always `catch { ... emit(emptyPreferences()) ... }` on the read path — `IOException` is an expected failure mode for first-run or corrupted stores, and swallowing it leaves the user with a spinning Flow.

## Keys

- Name keys `UPPER_SNAKE_CASE` and group in a private `object Keys`.
- Key strings in `snake_case` matching the property name.
- Never leak raw keys through the repository surface. The repository is the type boundary.

## Migrating from SharedPreferences

`SharedPreferencesMigration` does the one-shot copy:

```kotlin
val Context.settingsDataStore by preferencesDataStore(
    name = "settings",
    produceMigrations = { ctx ->
        listOf(SharedPreferencesMigration(ctx, "legacy_prefs"))
    },
)
```

Ship it for one release, then remove the migration (and the legacy `SharedPreferences` file) in the next.

## Multi-process

**DataStore is not multi-process safe.** If you have a widget, a `:remote` process, or a background service in a separate process, either:
- Funnel all reads/writes through a single process (bind to it via a `ContentProvider` facade), or
- Use `MultiProcessDataStore` from androidx `datastore-core` (preferences variant available since 1.1).

Don't open the same file from two processes with the single-process API — it corrupts silently.

## Testing

Use `PreferenceDataStoreFactory.create` with a temp directory in tests:

```kotlin
@Test fun setTheme_updates_flow() = runTest {
    val tmp = TemporaryFolder().apply { create() }
    val store = PreferenceDataStoreFactory.create(scope = backgroundScope) {
        tmp.newFile("settings.preferences_pb")
    }
    val repo = SettingsRepositoryImpl(store)
    repo.setTheme(AppTheme.DARK)
    assertEquals(AppTheme.DARK, repo.theme.first())
}
```

## Hard nos

- No `runBlocking { store.data.first() }` on the main thread.
- No writes from a `@Composable` — go through the repository + ViewModel.
- No exposing `DataStore<Preferences>` to UI layers.
- No storing secrets. Use `EncryptedSharedPreferences` or Keystore.
