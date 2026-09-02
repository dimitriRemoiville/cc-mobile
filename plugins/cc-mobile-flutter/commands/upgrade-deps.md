---
description: Upgrade Flutter/Dart dependencies from `pubspec.yaml` with a dry-run diff before applying. Self-sufficient — resolves latest stable per package directly from the pub.dev API.
argument-hint: "[--dry-run | --apply] [--major] [--package=<name>] [--group=core|networking|persistence|codegen|firebase|testing]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task, WebFetch
---

# /upgrade-deps

Upgrade dependencies declared in `pubspec.yaml`. Resolution is done by walking each package's pub.dev metadata directly so this command works on a freshly-scaffolded project with no extra tooling.

## Steps

1. Locate `pubspec.yaml`. Bail if it doesn't exist.

2. **Resolve the latest stable for each package by `WebFetch`-ing `https://pub.dev/api/packages/<name>`.** The JSON contains `latest.version`. Filter out any pre-release suffix — anything containing `-dev`, `-alpha`, `-beta`, `-rc`, `-pre`, `-edge`. Walk `versions[]` backwards if `latest.version` itself is a pre-release tag.
   - **Optional speedup (hint only):** `dart pub outdated --mode=null-safety` is built-in and offline-friendly; treat its output as a starting hint, **still verify via the pub.dev API** because the local lock may be stale relative to upstream.

3. Inspect both `dependencies:` and `dev_dependencies:` in `pubspec.yaml`. If `dependency_overrides:` is present, **list those packages but don't auto-bump them** — overrides exist for a reason; surface them so the user can decide manually.

4. Build a proposed diff for `pubspec.yaml`:
   - Default: bump within current major as a caret range (`^X.Y.Z`).
   - `--major`: allow major bumps; bumping across a major still requires `--package=<name>` to avoid surprise churn.
   - Skip any line with a trailing `# pin: <reason>` comment.
   - Group output by area: Flutter core (`flutter_bloc`, `bloc`, `go_router`, `go_router_builder`, `get_it`), networking (`dio`, `retrofit`, `pretty_dio_logger`), persistence (`drift`, `sqflite`, `shared_preferences`, `flutter_secure_storage`), codegen (`freezed`, `freezed_annotation`, `json_serializable`, `json_annotation`, `build_runner`), Firebase (`firebase_core` + all `firebase_*` plugins), testing (`mocktail`, `bloc_test`, `alchemist`, `golden_toolkit`, `flutter_test` SDK), other.

5. **Compatibility traps** — cross-link `${CLAUDE_PLUGIN_ROOT}/skills/flutter-app-skeleton/SKILL.md`'s "Compatibility traps" table if present; otherwise enforce these by hand:
   - **Flutter SDK ↔ Dart SDK** move together. If `environment.flutter` or `environment.sdk` in `pubspec.yaml` is bumped, both bounds must reflect the same Flutter release.
   - **`firebase_core` + all `firebase_*` plugins** must move on the same major together. A single out-of-sync plugin breaks the iOS pod resolution. Either bump them all or skip the Firebase group.
   - **`freezed` ↔ `freezed_annotation`** and **`json_serializable` ↔ `json_annotation`** majors stay aligned.
   - **`flutter_bloc` ↔ `bloc_test`** majors stay aligned.
   - **`go_router` ↔ `go_router_builder`** majors stay aligned.

6. **Dry-run (default)**: print the proposed `pubspec.yaml` diff to the user. Stop. Ask: "Apply?"

7. **Apply** (`--apply`):
   - Write the new `pubspec.yaml`.
   - `flutter pub get` to resolve and regenerate `pubspec.lock`.
   - If the project uses codegen, `dart run build_runner build --delete-conflicting-outputs`.
   - `flutter analyze` and `flutter test` to validate.
   - **If anything fails, revert both `pubspec.yaml` and `pubspec.lock`** to their pre-run state and surface the error. Do not leave the repo in a broken state.

8. Summarize:
   - Bumped (by group), each with old → new.
   - Skipped (pinned, pre-release, override, trap-blocked).
   - Post-bump checks: pub get result, build_runner result, analyze result, test result.

## Guard rails

- **Never bump past a known-incompatible major** without explicit `--package=<name>` targeting. Major bumps across Flutter SDK / Firebase / codegen usually involve coordinated migrations.
- For `--group=codegen`, always re-run `build_runner` even on a patch bump — generator metadata can shift between minors.
- For `--group=firebase`, remind to run `flutterfire configure` to re-sync platform files (Android `google-services.json`, iOS `GoogleService-Info.plist`).
- For any Dio major bump, flag the interceptor API and `BaseOptions` shape — both have shifted across recent majors.

Delegate breakage triage to `flutter-build-expert` via the `Task` tool — that agent owns the pub / build_runner / native-plugin side.
