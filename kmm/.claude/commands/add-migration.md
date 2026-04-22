---
description: Add a SQLDelight schema migration (.sqm file) with a verifyMigrations gradle task + test.
argument-hint: <to_version> <short-description>
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /add-migration

Arguments: `$ARGUMENTS` -> `<to_version> <description>`, e.g. `4 add-archived-column`.

SQLDelight auto-derives the `from` version as `<to> - 1` — the new `.sqm` file migrates from that baseline forward.

## Steps

1. Locate the SQLDelight database definition in `shared/build.gradle.kts`:
   - Confirm `verifyMigrations = true`.
   - Confirm `schemaOutputDirectory = file("src/commonMain/sqldelight/.../schemas")`.
2. Confirm a schema `.db` file exists for `<to> - 1` in the `schemas/` directory. That's the golden pre-migration snapshot. If missing, bail: run `./gradlew :shared:generate<DbName>Schema` on the previous HEAD first.
3. Ask the user (1 round-trip) for the schema change in SQL terms.
4. Generate the migration file:
   - Path: `shared/src/commonMain/sqldelight/<package>/migrations/<to>.sqm`.
   - Contents: one or more SQL statements (no trailing `.sq` syntax — `.sqm` is raw SQL).
5. Update the `.sq` files so queries match the post-migration shape. SQLDelight validates this at build time.
6. If the change renames a column or table, update every `.sq` file that references it.
7. Generate a test:
   - File: `shared/src/commonTest/kotlin/.../<Db>MigrationTest.kt`.
   - Uses the `JdbcSqliteDriver(IN_MEMORY)` + `<Db>.Schema.migrate(driver, <to-1>, <to>)`.
   - Seeds data at the old version, migrates, asserts data shape at the new version.
8. Run:
   - `./gradlew :shared:verifySqlDelightMigration` (fails if the migration + schema produce different results from the golden).
   - `./gradlew :shared:jvmTest --tests "*<Db>MigrationTest*"`.
9. Commit checklist:
   - New `.sqm` file.
   - Updated `.sq` files if any schema objects were renamed/dropped.
   - New schema `<to>.db` is regenerated and committed (produced by the build).
   - Test covers at least one row round-trip.

## Hard rules

- Forward-only. Never edit a shipped `.sqm`.
- Never delete a historic `.sqm`.
- `verifyMigrations = true` must stay on.
- If the change is `DROP COLUMN` on SQLite < 3.35, do create-new-table + copy + drop + rename.

Delegate tricky multi-table recreates to `kmm-reviewer` before running.
