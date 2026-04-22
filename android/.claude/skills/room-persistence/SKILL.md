---
name: room-persistence
description: Room (KSP) patterns for this Android project — entities, DAOs, type converters, Flow queries, migrations (auto + manual), testing with in-memory databases. Load whenever writing or reviewing code under `data/local/`.
---

# Room persistence

## Setup

Room with KSP, not kapt. In `libs.versions.toml` (resolve `<latest-stable>` to the newest non-alpha release at scaffold time):

```toml
[versions]
room = "<latest-stable>"

[libraries]
room-runtime = { module = "androidx.room:room-runtime", version.ref = "room" }
room-ktx = { module = "androidx.room:room-ktx", version.ref = "room" }
room-compiler = { module = "androidx.room:room-compiler", version.ref = "room" }
room-testing = { module = "androidx.room:room-testing", version.ref = "room" }
```

Module `build.gradle.kts`:

```kotlin
plugins { alias(libs.plugins.ksp) }
dependencies {
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)
    androidTestImplementation(libs.room.testing)
}
room { schemaDirectory("$projectDir/schemas") }
```

Commit the `schemas/` directory — it's the source of truth for auto-migrations.

## Entity

```kotlin
@Entity(
    tableName = "orders",
    indices = [Index("customer_id"), Index(value = ["created_at"], orders = [Index.Order.DESC])],
)
data class OrderEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "customer_id") val customerId: String,
    @ColumnInfo(name = "total_cents") val totalCents: Long,
    @ColumnInfo(name = "status") val status: String,
    @ColumnInfo(name = "created_at") val createdAt: Long,
)
```

- Column names in `snake_case`, property names in `camelCase`. Always explicit — don't rely on auto-derivation.
- Every foreign key column gets an `Index`. Missing indexes show up as silent full-table scans.
- Store timestamps as `Long` (epoch ms). `kotlinx-datetime` `Instant` round-trips via a TypeConverter.
- Prefer `String` primary keys for domain identity (UUIDs). Auto-increment `Int` is fine for join tables.

## Type converters

```kotlin
class AppTypeConverters {
    @TypeConverter fun instantToLong(value: Instant?): Long? = value?.toEpochMilliseconds()
    @TypeConverter fun longToInstant(value: Long?): Instant? = value?.let(Instant::fromEpochMilliseconds)

    @TypeConverter fun orderStatusToString(s: OrderStatus): String = s.name
    @TypeConverter fun stringToOrderStatus(s: String): OrderStatus = OrderStatus.valueOf(s)
}

@Database(entities = [OrderEntity::class], version = 1, exportSchema = true)
@TypeConverters(AppTypeConverters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun orderDao(): OrderDao
}
```

Register converters on the database, not individual DAOs. One `AppTypeConverters` class avoids splintering.

## DAO

```kotlin
@Dao
interface OrderDao {
    @Query("SELECT * FROM orders WHERE id = :id")
    suspend fun get(id: String): OrderEntity?

    @Query("SELECT * FROM orders WHERE customer_id = :customerId ORDER BY created_at DESC")
    fun observeByCustomer(customerId: String): Flow<List<OrderEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(order: OrderEntity)

    @Upsert
    suspend fun upsertAll(orders: List<OrderEntity>)

    @Query("DELETE FROM orders WHERE id = :id")
    suspend fun delete(id: String)
}
```

- `suspend` for one-shot, `Flow<...>` for observation. Room handles cancellation + invalidation.
- Prefer `@Upsert` (SQLite `UPSERT`) over `REPLACE` inserts — preserves child rows on composite schemas.
- Never expose a `LiveData` DAO method in new code.

## Repository boundary

The repository maps entities to domain models; the DAO stays behind the boundary.

```kotlin
class OrderRepositoryImpl @Inject constructor(
    private val dao: OrderDao,
) : OrderRepository {
    override fun observeByCustomer(customerId: String): Flow<List<Order>> =
        dao.observeByCustomer(customerId).map { list -> list.map(OrderEntity::toDomain) }

    override suspend fun save(order: Order) = dao.upsert(order.toEntity())
}
```

## Migrations

**Prefer auto-migrations.** Declare the bump + any renames:

```kotlin
@Database(
    entities = [OrderEntity::class, CustomerEntity::class],
    version = 2,
    autoMigrations = [AutoMigration(from = 1, to = 2)],
    exportSchema = true,
)
abstract class AppDatabase : RoomDatabase()
```

For renames, annotate the entity diff:

```kotlin
@RenameColumn(tableName = "orders", fromColumnName = "total", toColumnName = "total_cents")
class OrdersV1ToV2 : AutoMigrationSpec
```

**Use manual migrations** when auto can't handle it (data transform, split columns, backfill):

```kotlin
val MIGRATION_2_3 = object : Migration(2, 3) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE orders ADD COLUMN currency TEXT NOT NULL DEFAULT 'USD'")
        db.execSQL("UPDATE orders SET currency = 'EUR' WHERE total_cents >= 100000")
    }
}
Room.databaseBuilder(context, AppDatabase::class.java, "app.db")
    .addMigrations(MIGRATION_2_3)
    .build()
```

**Never use `fallbackToDestructiveMigration()` in release builds.** Debug-only behind a build flag.

Every manual migration gets a test with a golden pre-migration DB captured in `src/androidTest/assets/databases/`.

## Testing

```kotlin
@RunWith(AndroidJUnit4::class)
class OrderDaoTest {
    private lateinit var db: AppDatabase
    private lateinit var dao: OrderDao

    @Before fun setup() {
        db = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            AppDatabase::class.java,
        ).allowMainThreadQueries().build()
        dao = db.orderDao()
    }

    @After fun teardown() = db.close()

    @Test fun upsert_then_get_roundtrips() = runTest {
        val order = OrderEntity("id-1", "cust-1", 1000, "PAID", 0)
        dao.upsert(order)
        assertEquals(order, dao.get("id-1"))
    }
}
```

Migration tests use `MigrationTestHelper`:

```kotlin
@get:Rule val helper = MigrationTestHelper(
    InstrumentationRegistry.getInstrumentation(), AppDatabase::class.java,
)

@Test fun migrate_2_to_3() {
    helper.createDatabase("test.db", 2).apply {
        execSQL("INSERT INTO orders VALUES ('id-1', 'c', 100000, 'PAID', 0)")
        close()
    }
    val db = helper.runMigrationsAndValidate("test.db", 3, true, MIGRATION_2_3)
    db.query("SELECT currency FROM orders WHERE id = 'id-1'").use { c ->
        c.moveToFirst()
        assertEquals("EUR", c.getString(0))
    }
}
```

## Hard nos

- No `allowMainThreadQueries()` outside tests.
- No `Transformations.map` on a `LiveData` — use `Flow`.
- No DAO method returning `List<...>` as a suspend _and_ `Flow<List<...>>` for the same query. Pick one per use site.
- No exposing Room entities above `data/`. Map to domain at the repository.
- No dropping `exportSchema`. It's what lets auto-migrations work and what CI reviews.
