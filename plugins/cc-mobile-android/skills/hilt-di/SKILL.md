---
name: hilt-di
description: How Hilt is wired up and used in this project. Load when adding a new injectable, creating a Hilt module, setting up a new ViewModel, wiring a repository, writing Hilt-aware tests, or debugging a DI error.
---

# Hilt dependency injection

## Setup (reference)

- `Application` class annotated with `@HiltAndroidApp`.
- Every `Activity` / `Fragment` that injects: `@AndroidEntryPoint`.
- Every ViewModel: `@HiltViewModel`, constructor-injected, retrieved via `hiltViewModel()` in the Route composable.
- Hilt plugin in `libs.versions.toml` and applied on every module that participates.
- Use **KSP** for the Hilt compiler (`ksp(libs.hilt.compiler)`).

## Where modules live

Co-locate modules with the implementations they bind.

```
data/di/OrderDataModule.kt   # provides OrderApi, binds OrderRepositoryImpl
core/di/NetworkModule.kt     # provides OkHttp, Retrofit
core/di/DispatcherModule.kt  # provides Dispatchers
```

Avoid a single `AppModule` that knows about everything.

## `@Provides` vs `@Binds`

- **`@Binds`** when you're mapping an interface to an implementation whose constructor has `@Inject`. Declare as an abstract function in an abstract class / interface module. Zero runtime cost.
- **`@Provides`** when you need to construct the object yourself (e.g., configure a Retrofit instance).

```kotlin
@Module
@InstallIn(SingletonComponent::class)
abstract class OrderDataModule {
    @Binds @Singleton
    abstract fun bindOrderRepository(impl: OrderRepositoryImpl): OrderRepository
}

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides @Singleton
    fun provideOkHttp(): OkHttpClient = OkHttpClient.Builder()
        .addInterceptor(HttpLoggingInterceptor())
        .build()

    @Provides @Singleton
    fun provideRetrofit(ok: OkHttpClient): Retrofit = Retrofit.Builder()
        .baseUrl(BuildConfig.API_BASE_URL)
        .client(ok)
        .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
        .build()

    @Provides @Singleton
    fun provideOrderApi(retrofit: Retrofit): OrderApi = retrofit.create()
}
```

## Components (scopes) to know

- `SingletonComponent` — app lifetime. Use for repositories, Retrofit, Room.
- `ViewModelComponent` — one per ViewModel. Use for ViewModel-scoped helpers.
- `ActivityRetainedComponent` — survives config changes, one per activity.
- `ActivityComponent`, `FragmentComponent`, `ViewComponent` — usually not needed day-to-day.

Default to `SingletonComponent` unless you know you need something narrower.

## Qualifiers

When you have multiple instances of the same type, disambiguate:

```kotlin
@Qualifier annotation class IoDispatcher
@Qualifier annotation class DefaultDispatcher

@Module @InstallIn(SingletonComponent::class)
object DispatcherModule {
    @Provides @IoDispatcher fun provideIo(): CoroutineDispatcher = Dispatchers.IO
    @Provides @DefaultDispatcher fun provideDefault(): CoroutineDispatcher = Dispatchers.Default
}

class Repo @Inject constructor(
    @IoDispatcher private val io: CoroutineDispatcher,
)
```

## ViewModels

```kotlin
@HiltViewModel
class OrderViewModel @Inject constructor(
    private val submit: SubmitOrderUseCase,
    savedStateHandle: SavedStateHandle,
) : ViewModel()
```

- Retrieve with `val vm: OrderViewModel = hiltViewModel()` only in the Route composable.
- Never pass a ViewModel down to child composables. Pass state + callbacks.

## Testing with Hilt

- Use `@HiltAndroidTest` on the test class.
- `@get:Rule val hiltRule = HiltAndroidRule(this)` at the top, call `hiltRule.inject()` in `@Before`.
- Custom test application: `HiltTestApplication`, registered via a `CustomTestRunner`.
- Replace bindings per-test with `@BindValue` — much simpler than writing a whole test module for one-off swaps.

For **unit tests**, don't involve Hilt at all. Construct the class manually, pass fakes/mocks to the constructor. Hilt tests are for integration/Compose tests.

## Common errors and fixes

- **"No binding found for ..."** → the type isn't provided. Check if the implementation has `@Inject` constructor, or add a `@Provides` / `@Binds`.
- **"Found a dependency cycle"** → two classes `@Inject` each other directly or transitively. Extract an interface or break the cycle with a `Provider<T>`.
- **"...is already bound"** → duplicate binding, often because two modules both `@Provides` the same type. Remove one.
- **ViewModel fails to inject** → missing `@HiltViewModel`, or Activity missing `@AndroidEntryPoint`, or retrieving it with `viewModel()` instead of `hiltViewModel()`.
