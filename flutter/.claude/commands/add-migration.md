---
description: Add a drift schema migration with a schema snapshot and round-trip test.
argument-hint: <from_version> <to_version> <short-description>
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /add-migration

Arguments: `$ARGUMENTS` -> `<from> <to> <description>`, e.g. `3 4 add-archived-column`.

## Steps

1. Locate the drift `@DriftDatabase` class (usually `lib/data/local/app_database.dart`). Confirm:
   - `schemaVersion` getter matches `<from>`.
   - A `drift_schemas/` directory holds generated snapshots from previous versions (`drift_schema_v<from>.json`). If missing, run `dart run drift_dev schema dump lib/data/local/app_database.dart drift_schemas/` on the previous HEAD first.
2. Ask the user (1 round-trip) for the schema change — add column (with default), drop column, add table, add index, rename.
3. Generate:
   - Update the table/entity classes to match the new shape.
   - Bump `schemaVersion => <to>`.
   - Update `MigrationStrategy.onUpgrade` with the new `if (from < <to>) { ... }` block using the `m.` API (`m.addColumn`, `m.createTable`, `m.renameColumn`).
4. Generate the new schema snapshot:
   - `dart run drift_dev schema dump lib/data/local/app_database.dart drift_schemas/` produces `drift_schema_v<to>.json`.
5. Generate the migration test:
   - `test/data/local/migrations/v<from>_to_v<to>_test.dart`.
   - Uses `drift_dev`'s `SchemaVerifier` with the v<from> snapshot:
     - Create `schemaAt(<from>)`.
     - Insert rows via raw SQL matching the old shape.
     - Call `verifier.migrateAndValidate(db, <to>)`.
     - Re-open as the real `AppDatabase`, read rows, assert they survived.
6. Run:
   - `dart run build_runner build --delete-conflicting-outputs` (regenerates drift code).
   - `flutter test test/data/local/migrations/`.
7. Commit checklist:
   - New `drift_schema_v<to>.json` under version control.
   - `onUpgrade` forward-only branch added.
   - At least one row round-trip test.

## Hard rules

- Forward-only. Never edit `onUpgrade` branches for versions you've already shipped.
- Never ship a migration without a snapshot test.
- When bumping `drift`, re-run schema dumps if the generator's output format changed.
- For `DROP COLUMN` on old SQLite, use create-new-table + copy + drop + rename.

Delegate tricky re-creates to `flutter-reviewer` before running tests.
