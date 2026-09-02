# Reference — INCLUDE_ROOM additions

Only emit when `INCLUDE_ROOM` is true. The Room dependencies are already in `app/build.gradle.kts` (under the `// INCLUDE_ROOM` block in [app-module.md](app-module.md)).

Persistence is shared infrastructure, so it lives under `core/data/persistence/`. Per-feature DAOs/entities can be promoted to `<feature>/data/persistence/` later if a feature owns its own table.

## `app/src/main/java/{{PACKAGE_PATH}}/core/data/persistence/AppDatabase.kt`

```kotlin
package {{PACKAGE_ID}}.core.data.persistence

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

## `app/src/main/java/{{PACKAGE_PATH}}/core/data/persistence/SampleEntity.kt`

```kotlin
package {{PACKAGE_ID}}.core.data.persistence

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "samples")
data class SampleEntity(
    @PrimaryKey val id: String,
    val label: String,
)
```

## `app/src/main/java/{{PACKAGE_PATH}}/core/data/persistence/SampleDao.kt`

```kotlin
package {{PACKAGE_ID}}.core.data.persistence

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

## `app/src/main/java/{{PACKAGE_PATH}}/core/data/persistence/di/PersistenceModule.kt`

The `@Module` that lets the rest of the graph `@Inject SampleDao` (or any future DAO) without knowing about the Room builder. Without this, the entity + DAO files compile but are unreachable from a ViewModel — the analytics flag's `AnalyticsModule` is the parallel, and `INCLUDE_ROOM` should ship the same level of wiring.

```kotlin
package {{PACKAGE_ID}}.core.data.persistence.di

import android.content.Context
import androidx.room.Room
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import {{PACKAGE_ID}}.core.data.persistence.AppDatabase
import {{PACKAGE_ID}}.core.data.persistence.SampleDao
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object PersistenceModule {
    @Provides @Singleton
    fun provideAppDatabase(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, "app.db").build()

    @Provides
    fun provideSampleDao(db: AppDatabase): SampleDao = db.sampleDao()
}
```

Enable schema export in `app/build.gradle.kts` (inside the `android { }` block):

```kts
ksp { arg("room.schemaLocation", "$projectDir/schemas") }
```
