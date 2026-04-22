# Flutter app skeleton — drift + sqlcipher companion

Load this when `INCLUDE_DRIFT` is set. The core `SKILL.md` already contains the drift scaffold inline; this file is a **concentrated reference** for the drift bits so you don't have to re-read the 900-line main skill every time.

## pubspec adds

Run these `dart pub add` calls (grouped with the main skill's networking/DI group is fine):

```bash
dart pub add drift drift_flutter sqlcipher_flutter_libs path path_provider
dart pub add --dev drift_dev build_runner
```

Never add `sqlite3_flutter_libs` alongside `sqlcipher_flutter_libs`. The two provide conflicting SQLite natives and the build silently picks one.

## Files

Write these under `lib/core/database/`:

### `app_database.dart`

```dart
import 'package:drift/drift.dart';
import 'executor.dart';

part 'app_database.g.dart';

@DataClassName('SampleRow')
class Samples extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  @override
  Set<Column<Object>>? get primaryKey => {id};
}

@DriftDatabase(tables: [Samples])
class AppDatabase extends _$AppDatabase {
  AppDatabase(String passphrase) : super(openConnection(passphrase));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // forward-only migrations go here
        },
      );
}
```

### `executor.dart`

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

LazyDatabase openConnection(String passphrase) {
  return LazyDatabase(() async {
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));
    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        db.execute("PRAGMA key = '${_escape(passphrase)}'");
        db.execute('PRAGMA foreign_keys = ON;');
      },
      logStatements: false,
    );
  });
}

String _escape(String v) => v.replaceAll("'", "''");
```

## Passphrase source

- On first launch, read from `flutter_secure_storage`. If missing, generate 32 bytes of entropy (`Random.secure()` + base64url), store, then use.
- Never hardcode the passphrase in source or env vars.
- Never log it. Never pass it through an analytics breadcrumb.

## Repository boundary

The domain layer must not see drift types. Keep drift imports to `lib/data/` (repositories own the DAO, map to domain entities).

```dart
abstract class SampleRepository {
  Stream<List<SampleEntity>> watchAll();
  Future<void> upsert(SampleEntity e);
}
```

## Test wiring

Use an in-memory database in tests. Never hit SQLCipher in unit tests — it's slow and platform-gated.

```dart
QueryExecutor inMemoryExecutor() => NativeDatabase.memory();
```

Construct `AppDatabase.forTesting(inMemoryExecutor())` via a secondary constructor that accepts a raw executor.

## Hard nos

- No `sqlite3_flutter_libs` alongside `sqlcipher_flutter_libs`.
- No drift imports outside `lib/data/` or `lib/core/database/`.
- No passphrase in source / env / logs.
- No destructive migrations without an explicit user-approved flag.
