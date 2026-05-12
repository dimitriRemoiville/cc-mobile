---
description: Add a Room schema migration with test coverage for the pre-migration DB.
argument-hint: <from_version> <to_version> <short-description>
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task, AskUserQuestion
---

# /add-migration

Arguments: `$ARGUMENTS` -> `<from> <to> <description>`, e.g. `3 4 add-archived-column`.

## Steps

1. Locate the Room `@Database` class and note:
   - Current `version`.
   - `exportSchema = true` (bail if false: ask the user to enable and commit the current schema JSON first).
   - `schemaLocation` in KSP args (usually `$projectDir/schemas/`).
2. Validate the `from` version matches the current DB version. Bail with a clear error if it doesn't.
3. Confirm a schema JSON exists at `schemas/<package>.<DbClass>/<from>.json`. That's the golden pre-migration DB for the test.
4. Use `AskUserQuestion` (one round-trip, structured prompt) to gather the actual schema change. Don't ask the user to write SQL by hand — collect:
   - **Operation** (single-select): `ADD_COLUMN` / `DROP_COLUMN` (requires table recreate) / `CREATE_TABLE` / `CREATE_INDEX` / `RENAME_COLUMN` / `RENAME_TABLE` / `OTHER (free-text SQL)`.
   - **Target table** (free-text).
   - For `ADD_COLUMN` / `RENAME_COLUMN`: column name(s), SQL type (`TEXT` / `INTEGER` / `REAL` / `BLOB`), nullability (single-select `NULL` / `NOT NULL`), default value (free-text or `NONE`). The default matters: a `NOT NULL` add without a default fails on existing rows.
   - For `OTHER`: paste the SQL.
   Reject obviously-broken combinations (e.g. `NOT NULL` add with no default and no backfill) before generating the migration. If the change is non-trivial, hand off to `android-reviewer` for a sanity pass before running the test.
5. Generate:
   - The `Migration(from, to)` object, placed next to the `@Database` class (or in a `migrations/` package if >3 migrations exist).
   - Append it to the DB builder's `.addMigrations(...)`.
   - Bump the `@Database(version = <to>)`.
   - Update entity classes (add/remove fields) to match the new schema.
6. Generate the migration test:
   - File: `src/androidTest/java/.../<DbClass>MigrationTest.kt` (create if missing; otherwise append).
   - Uses `MigrationTestHelper` with the `<from>.json` golden.
   - Inserts 1-2 rows with the old schema, runs the migration, asserts shape + values in the new schema.
7. Run:
   - `./gradlew :<module>:kspDebugKotlin` (generates the new schema JSON at `<to>.json`).
   - `./gradlew :<module>:connectedDebugAndroidTest --tests "*<DbClass>MigrationTest*"` if an emulator is available; else flag and stop.
8. Commit checklist shown to user:
   - New `<to>.json` schema file is under version control.
   - Migration is `addMigrations(MIGRATION_<from>_<to>)` registered in the DB builder.
   - Test covers at least one row round-trip.

## Hard rules

- Forward-only. Never modify a shipped migration.
- Never use `.fallbackToDestructiveMigration()` in a migration PR.
- If the change is a `DROP COLUMN`, implement it as create-new-table + copy + drop-old + rename. Room can't drop columns in place before SQLite 3.35.
- If the change renames a column, require `@RenameColumn` on the entity for AutoMigration, or write the full CREATE-COPY-RENAME migration by hand.

Delegate tricky multi-table recreates to `android-reviewer` for a sanity pass before running the test.
