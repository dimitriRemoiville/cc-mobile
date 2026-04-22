---
name: retrofit-networking
description: Networking patterns for this project — Retrofit service definitions, OkHttp configuration, DTO design with kotlinx.serialization, error mapping, and how networking fits into the repository. Load when adding or editing any API call, interceptor, or serializer.
---

# Networking (Retrofit + OkHttp)

## The pipeline

```
domain.Repository       # domain types only
     ↓
data.RepositoryImpl     # calls API, maps, returns Result<DomainType>
     ↓
data.remote.Api         # Retrofit interface, returns DTOs
     ↓
OkHttpClient            # interceptors, timeouts, logging
```

Network errors are **mapped to domain errors at the repository boundary**. Nothing higher up should know about `HttpException` or `IOException`.

## Service definition

```kotlin
interface OrderApi {
    @GET("orders/{id}")
    suspend fun getOrder(@Path("id") id: String): OrderDto

    @GET("orders")
    suspend fun list(
        @Query("cursor") cursor: String? = null,
        @Query("limit") limit: Int = 20,
    ): PagedDto<OrderDto>

    @POST("orders")
    suspend fun create(@Body body: CreateOrderRequest): OrderDto
}
```

Rules:
- **Always `suspend`.** No `Call<T>`, no `Single<T>`.
- Return the DTO directly. Let Retrofit throw `HttpException` on non-2xx.
- Use typed `@Path`/`@Query`/`@Body`; avoid raw `Map<String, String>` except for truly dynamic cases.

## DTOs

Separate from domain models. Named `*Dto`. Annotated for the serializer in use:

```kotlin
@Serializable
data class OrderDto(
    val id: String,
    val items: List<OrderItemDto>,
    @SerialName("total_cents") val totalCents: Long,
    @SerialName("created_at") val createdAt: String,
)
```

- Nullability reflects the wire format, not what the domain wants.
- Unknown enum values? Use `@JsonNames` (Moshi) or `@SerialName` + a default branch.

## Mapping DTO → domain

One-way functions, colocated with the DTO or in a `mapper/` package:

```kotlin
fun OrderDto.toDomain(): Order = Order(
    id = OrderId(id),
    items = items.map(OrderItemDto::toDomain),
    total = Money.fromCents(totalCents),
    createdAt = Instant.parse(createdAt),
)
```

Never expose DTOs beyond the data layer.

## Repository pattern

```kotlin
class OrderRepositoryImpl @Inject constructor(
    private val api: OrderApi,
    @IoDispatcher private val io: CoroutineDispatcher,
) : OrderRepository {

    override suspend fun getOrder(id: OrderId): Result<Order> = withContext(io) {
        runCatching { api.getOrder(id.raw).toDomain() }
            .mapError(::toDomainError)
    }
}

private fun toDomainError(t: Throwable): DomainError = when (t) {
    is HttpException -> when (t.code()) {
        401 -> DomainError.Unauthorized
        404 -> DomainError.NotFound
        in 500..599 -> DomainError.Server
        else -> DomainError.Unknown(t.code().toString())
    }
    is IOException -> DomainError.Network
    else -> DomainError.Unknown(t.message.orEmpty())
}
```

`mapError` is a tiny extension:

```kotlin
inline fun <T, E : Throwable> Result<T>.mapError(transform: (Throwable) -> E): Result<T> =
    fold(onSuccess = { Result.success(it) }, onFailure = { Result.failure(transform(it)) })
```

## OkHttp configuration

```kotlin
@Provides @Singleton
fun provideOkHttp(
    authInterceptor: AuthInterceptor,
): OkHttpClient = OkHttpClient.Builder()
    .connectTimeout(10, TimeUnit.SECONDS)
    .readTimeout(30, TimeUnit.SECONDS)
    .addInterceptor(authInterceptor)
    .apply {
        if (BuildConfig.DEBUG) {
            addInterceptor(HttpLoggingInterceptor().apply { level = Level.BODY })
        }
    }
    .build()
```

- Logging **only in debug**. Never log bodies in release — they contain PII.
- Auth header via an `Interceptor` that reads from a token store. Don't put the token in the URL.

## Retrofit with kotlinx.serialization

```kotlin
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
```

`ignoreUnknownKeys = true` is critical — don't let a new server field break parsing.

## Streaming / pagination

- Use Paging 3 (`androidx.paging`) if the API is cursor-based and the list is long. DTOs go through a `RemoteMediator`.
- Otherwise a simple `Flow<PagingState>` in the ViewModel is fine for small lists.

## Common pitfalls

- **Non-suspend service methods.** Old `Call<T>` APIs leak callbacks. Migrate.
- **Letting `HttpException` bubble into the ViewModel.** Map it at the repository.
- **Logging interceptor in release.** Check `BuildConfig.DEBUG`.
- **Using `@Body Map<String, Any>`.** Define a typed request class; `Any` breaks serialization.
- **Retrofit created per call.** It's a `@Singleton`. Building it is expensive.
