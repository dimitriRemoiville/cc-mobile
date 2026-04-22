---
description: Upgrade Flutter/Dart dependencies with a dry-run diff before applying.
argument-hint: [--dry-run | --apply] [--major] [--package=<name>]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /upgrade-deps

1. Read `pubspec.yaml`. Bail if missing.
2. Run `dart pub outdated --mode=null-safety` (captures latest and currently-resolved). Also `dart pub outdated --json` for parse-friendly output.
3. Build a proposed diff for `pubspec.yaml`:
   - Default: bump within current major (respect caret ranges).
   - `--major`: allow major bumps; bumping across a major requires `--package=<name>` to avoid surprise churn.
   - Skip any line that has a `# pin:` trailing comment.
4. Group by area: Flutter core (`flutter_bloc`, `go_router`, `get_it`), networking (`dio`, `retrofit`), persistence (`drift`, `sqflite`), codegen (`freezed`, `json_serializable`, `build_runner`), Firebase, testing (`mocktail`, `bloc_test`, `flutter_test` SDK), other.
5. **Dry-run (default)**: print the proposed YAML diff. Stop. Ask: "Apply?"
6. **Apply**:
   - Edit `pubspec.yaml`.
   - `dart pub get`.
   - Run `dart run build_runner build --delete-conflicting-outputs` if the project uses codegen.
   - `dart analyze`.
   - `flutter test`.
   - Revert on failure.
7. Summarize: bumped, skipped, analyze result, test result.

## Guard rails

- Never bump past a major without `--package=<name>`.
- When bumping `flutter_bloc`, also check `bloc_test` is on the matching major.
- When bumping `freezed` or `json_serializable`, always re-run `build_runner`.
- When bumping any Firebase plugin, suggest running `flutterfire configure` to re-sync platform files.

Delegate breakage triage to `flutter-build-expert`.
