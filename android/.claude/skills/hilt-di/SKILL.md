---
name: hilt-di
description: Project-specific Hilt conventions — feature-first module locations, `hiltViewModel()`-in-Route-only rule, KSP-only compiler, single shared `OkHttpClient` between Retrofit and Coil, and the test-time `@BindValue` shortcut. Load when adding a new injectable, creating a Hilt module, setting up a new ViewModel, wiring a repository, writing Hilt-aware tests, or debugging a DI error.
---

# Hilt (project delta)

For Hilt fundamentals — `@HiltAndroidApp`, `@AndroidEntryPoint`, `@HiltViewModel`, component scopes, `@Provides` vs `@Binds`, qualifiers, `Provider<T>` / `Lazy<T>` — read the [official Hilt guide](https://developer.android.com/training/dependency-injection/hilt-android). The canonical `NetworkModule` / `PersistenceModule` / `DataStoreModule` / `AnalyticsModule` templates live in `.claude/skills/android-app-skeleton/references/core-data.md` (and the optional-room / optional-datastore references). This file documents only the project's specific decisions.

## When this applies

Hilt with KSP. On an existing app:

- **Koin** (`org.koin.*`, `koinViewModel(...)`, `module { ... }`) → skip this skill entirely; Koin's runtime DSL is incompatible with Hilt's compile-time graph. Apply only stack-agnostic principles (constructor injection, no service locator).
- **Plain Dagger 2** (no `@HiltAndroidApp`, manual `@Component`) → many idioms transfer, but Hilt's component hierarchy and `@HiltViewModel` shortcut don't exist. Don't push Hilt-specific patterns.
- **Manual constructor wiring / no DI framework** → don't refactor unless asked.
- **kapt instead of KSP** → it works; flag the build-time cost only when discussing the build, not as a correctness issue.

## Project rules

- **KSP-only.** `ksp(libs.hilt.compiler)`. The reviewer rejects `kapt(libs.hilt.compiler)` and any `kapt` plugin in `app/build.gradle.kts`.
- **`hiltViewModel()` is called only in the Route composable.** Never in child composables, never passed down the tree. The Route owns the VM; the Screen takes state + callbacks. See `compose-ui` for the Route/Screen split.
- **Default to `SingletonComponent`.** Reach for `ViewModelComponent` / `ActivityRetainedComponent` only when you have a concrete reason (short-lived helpers, things that must die with the ViewModel).
- **One shared `OkHttpClient`** between Retrofit and Coil. Coil's network fetcher reuses it via `{{APP_CLASS}}.newImageLoader`. **Don't `@Provides` a second `OkHttpClient`** for images.

## Where modules live (feature-first)

Co-locate modules with the implementations they bind:

```
<feature>/data/di/<Feature>DataModule.kt   # binds <Feature>RepositoryImpl, feature-specific APIs
core/data/network/di/NetworkModule.kt      # OkHttp, Json, Retrofit, SampleApi
core/data/analytics/AnalyticsModule.kt     # @Binds AnalyticsTracker → Noop or Firebase impl
core/data/persistence/di/PersistenceModule.kt   # INCLUDE_ROOM: AppDatabase, DAOs
core/data/datastore/di/DataStoreModule.kt       # INCLUDE_DATASTORE: AppPreferences
core/di/DispatcherModule.kt                # cross-cutting: dispatchers, clocks, IDs
```

`core/data/network/di/` is correct because network providers belong to the data layer's networking subpackage. Reach for `core/di/` only for things that don't belong to a single layer. **Avoid a single `AppModule` that knows about everything.**

## Testing — `@BindValue` over test modules

**Unit tests don't involve Hilt.** Construct the class manually and pass fakes / mocks to the constructor. The scaffold's `FeedViewModelTest` (in `.claude/skills/android-app-skeleton/references/tests.md`) is the canonical example.

**Hilt-aware integration / Compose tests** use the Hilt test rule **and `@BindValue`** to swap one binding per test:

```kotlin
@HiltAndroidTest
class FeedScreenTest {
    @get:Rule(order = 0) val hiltRule = HiltAndroidRule(this)
    @get:Rule(order = 1) val composeRule = createAndroidComposeRule<HiltTestActivity>()

    @BindValue @JvmField
    val analytics: AnalyticsTracker = NoopAnalyticsTracker()

    @Before fun setup() { hiltRule.inject() }
}
```

`@BindValue` is **far simpler than writing a `@TestInstallIn` test module** for one-off replacements. Use it for `AnalyticsTracker`, fake repositories, and any other singleton you want to control per-test. The custom `CustomTestRunner` + `HiltTestApplication` are set up by the scaffold's `app/build.gradle.kts`.

## Common error pointers (project-specific only)

- **"No binding found for X" on a third-party type** (e.g. `OkHttpClient`, `Json`) — it lives in `core/data/network/di/NetworkModule.kt`. Don't `@Provides` it locally.
- **ViewModel fails to inject in a composable** — most common cause is `viewModel()` instead of `hiltViewModel()` in the Route. Second most common: missing `@AndroidEntryPoint` on the host Activity.
- **AGP 9 + Hilt version mismatch** (`Cannot add extension with name 'kotlin'` / `Could not find AGP base extension`) — see `.claude/skills/android-app-skeleton/references/root-files.md` → "Compatibility traps."

For generic Hilt error messages ("Found a dependency cycle", "X is already bound"), the [official guide's troubleshooting section](https://developer.android.com/training/dependency-injection/hilt-android) is more thorough than restating it here.
