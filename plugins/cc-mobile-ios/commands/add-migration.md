---
description: Add a SwiftData schema migration with a VersionedSchema + MigrationPlan stage and tests.
argument-hint: <from_version> <to_version> <short-description>
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /add-migration

Arguments: `$ARGUMENTS` -> `<from> <to> <description>`, e.g. `V2 V3 add-archived-flag`.

## Steps

1. Locate the SwiftData schema definitions. Confirm a `VersionedSchema` exists for the current version (e.g. `SchemaV2`). If the project is still on an un-versioned `@Model` setup, first refactor to `VersionedSchema` + `SchemaMigrationPlan` — delegate that one-off to `ios-reviewer`.
2. Validate `from` matches the latest `VersionedSchema`. Bail otherwise.
3. Ask the user (1 round-trip) for the schema change in model terms:
   - Add property (lightweight).
   - Rename property (`MigrationStage.custom` with willMigrate/didMigrate).
   - Remove property.
   - Add/remove relationship.
   - Change property type.
4. Generate:
   - A new `enum SchemaV<to>: VersionedSchema` with the updated `@Model` types.
   - A `MigrationStage` in the `MigrationPlan`:
     - `.lightweight(fromVersion: SchemaV<from>.self, toVersion: SchemaV<to>.self)` when only adding optional properties or adding models.
     - `.custom(..., willMigrate:, didMigrate:)` for renames, required property additions with defaults, splits.
   - Update the `ModelContainer` construction to use the migration plan.
5. Generate a test:
   - File: `Tests/PersistenceTests/SchemaV<from>ToV<to>Tests.swift`.
   - Creates an in-memory container with `SchemaV<from>`, inserts rows, closes the container.
   - Re-opens with the migration plan targeting `SchemaV<to>`, asserts shape + values survived the migration.
6. Run `swift test --filter SchemaV<from>ToV<to>Tests` (or `xcodebuild test -only-testing:<scheme>Tests/SchemaV<from>ToV<to>Tests`).
7. Commit checklist:
   - New `SchemaV<to>` is defined once and never edited after ship.
   - `MigrationPlan.stages` lists all stages in order.
   - Test covers at least one row round-trip.

## Hard rules

- Forward-only. Never edit `SchemaV<n>` after it ships.
- Never reuse an old `VersionedSchema` type name for a new version.
- If a property becomes required and has no default, use `.custom` and populate in `willMigrate`.
- If you rename a model type, keep the old typealias in `SchemaV<from>` so the migration can still reference it.

Delegate tricky `.custom` stages to `ios-reviewer` before running tests.
