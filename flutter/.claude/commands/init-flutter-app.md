---
description: Scaffold a fresh Flutter app with this project's conventions — Clean Architecture, flutter_bloc, typed go_router with StatefulShellRoute (Home + Feed/Profile bottom-nav), get_it, dio, freezed, fpdart, a clean-arch IAnalyticsTracker layer, and (optionally) drift + Firebase + notifications + workmanager.
argument-hint: "[app_name]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task, AskUserQuestion, WebFetch
---

# /init-flutter-app

You are scaffolding a brand-new Flutter application from scratch, using the conventions defined in this repository. **Nothing is generated until the clarifying questions in Phase 0 have been answered** — the defaults and optional features materially change the files that get written.

## Phase 0 — Gather inputs (one round-trip)

Propose a default configuration up front and ask the user to confirm or override in **one** round-trip. Do not proceed without an explicit confirm.

Propose these defaults (adjust `package_name` and `org_domain` based on `$ARGUMENTS` if provided):

- **App display name**: derived from `$ARGUMENTS` titlecased, else "New App".
- **Package name** (Dart pub / `lib/` folder): snake_case of `$ARGUMENTS` if given, else `new_app`.
- **Organization reverse domain**: `com.example` (must be overridden by user for a real project).
- **Include drift + sqlcipher persistence**: yes.
- **Include Firebase (Crashlytics + Analytics + Remote Config)**: no. *(Either way the scaffold ships an `IAnalyticsTracker` interface in `lib/core/analytics/` plus a `NoopAnalyticsTracker`. With Firebase on, `container.dart` binds the interface to a defensive `FirebaseAnalyticsTracker` instead.)*
- **Include local notifications**: no.
- **Include background work (workmanager)**: no.
- **Goldens library**: `alchemist`.

Present this as one `AskUserQuestion` with a single "Confirm defaults" option + individual override options for any item the user wants to change. Re-ask only if Firebase is turned on (warn about the manual `flutterfire configure` step and per-flavor plists).

Summarize the final plan in one short paragraph — what will be generated, what is skipped, what manual steps remain (flavor Gradle/Xcode config, `flutterfire configure` if Firebase is on). Proceed when confirmed.

## Phase 1 — Load the blueprint

Read `.claude/skills/flutter-app-skeleton/SKILL.md` in full. It is the authoritative source for:

- The 11-step execution order
- Every file template in `lib/`, `test/`, root configs
- Placeholder names (`{{APP_NAME}}`, `{{APP_CLASS}}`, `{{ORG_DOMAIN}}`, `{{APP_DISPLAY_NAME}}`)
- Feature-flag blocks (`INCLUDE_DRIFT`, `INCLUDE_FIREBASE`, `INCLUDE_NOTIFICATIONS`, `INCLUDE_WORKMANAGER`)
- The hard rules (no `sqlite3_flutter_libs` alongside sqlcipher, no mockito, no dartz, no Equatable in new code, no string routes, no `allowReassignment`, never pin `intl: any`)

Do not improvise file contents — use the skill as the source of truth and substitute placeholders.

## Phase 1.5 — Verify the Flutter SDK floor (online + local)

Pub.dev versions are resolved live by `dart pub add`, so the only thing the user's local environment can pin too low is the **Flutter SDK itself**. Sanity-check it before touching anything.

1. **Local check.** Run `flutter --version` and parse the first line (`Flutter <X.Y.Z> ...`). Compare to the SDK floor declared in the seed `pubspec.yaml` from the skill (`environment.flutter`). If lower, stop and ask the user to upgrade — do not lower the floor.
2. **Online sanity check (optional).** `WebFetch` `https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json` (or `_linux.json` / `_windows.json`). Look up the hash at `current_release.stable` in the `releases` array to find the latest stable version string. Report if the user's local Flutter is more than one minor version behind the published stable — old enough to start hitting compatibility traps in the skill's table.

Don't try to resolve pub versions yourself — `dart pub add` does that in Phase 2 step 2 and writes real caret constraints into the project's `pubspec.yaml`. Your job here is to make sure the Flutter SDK on PATH won't cap that resolution to something too old.

## Phase 2 — Execute the scaffold

Follow the skill's 11-step procedure in order. In outline:

1. Run `flutter create --org <ORG_DOMAIN> --platforms=android,ios --project-name <APP_NAME> <APP_NAME>` in the parent directory.
2. `cd <APP_NAME>`. Seed `pubspec.yaml` with the non-dependency shell from the skill, then add dependencies with `dart pub add` (grouped as shown). Do not hardcode version numbers — `dart pub add` resolves current compatible versions live and writes the pins into the generated `pubspec.yaml`. After `pub get` succeeds, sanity-check the resolved set against the skill's "Compatibility traps" table — those are the failure patterns to recognize, not version pins. Never use `intl: any` — if pub writes `intl: any`, replace with a caret constraint on whatever was resolved.
3. Replace `analysis_options.yaml` with the blueprint version (promotions to `error` for `avoid_print`, `unawaited_futures`, `prefer_const_constructors`, etc.).
4. Add the blueprint `build.yaml` for codegen.
5. Delete `lib/main.dart` and the default `test/widget_test.dart`. Create the full `lib/` tree from the skill:
   - `main_dev.dart` + `main_prod.dart` (flavor entry points; under `INCLUDE_FIREBASE` also wire `Firebase.initializeApp` + Crashlytics handlers as shown in `_firebase.md`)
   - `app_initializer.dart` (calls `analytics.setCollectionEnabled(!kDebugMode)` after DI is up — works regardless of Firebase) + `{{APP_NAME}}_app.dart`
   - `core/analytics/i_analytics_tracker.dart`, `analytics_event.dart` (sealed taxonomy: `HomeViewed`, `FeedViewed`, `ProfileViewed`, `ItemTapped`, `ScreenOpenedFromDeepLink`), `noop_analytics_tracker.dart` (always emit)
   - `core/analytics/firebase_analytics_tracker.dart` (only under `INCLUDE_FIREBASE` — defensive, no-ops when `Firebase.apps.isEmpty`)
   - `core/config/flavor.dart` + `app_config.dart`
   - `core/errors/failures.dart` (full sealed hierarchy)
   - `core/auth/auth_token_provider.dart` + `AuthFailureReason` enum
   - `core/logging/i_logger.dart` + `app_logger.dart`
   - `core/network/api_call_error_handling.dart` + `dio_factory.dart`
   - `core/di/container.dart` — registers `IAnalyticsTracker` (Noop by default, Firebase impl under `INCLUDE_FIREBASE`) and calls `registerHomeModule(sl)`
   - `core/database/app_database.dart` + `executor.dart` (only if `INCLUDE_DRIFT`)
   - `feature/home/di/home_module.dart`
   - `feature/home/presentation/pages/home_shell_page.dart` (Material 3 `NavigationBar` + `StatefulNavigationShell`), `feed_page.dart`, `profile_page.dart`
   - `feature/home/presentation/cubit/feed_cubit.dart` + `feed_state.dart` (freezed) + `profile_cubit.dart` + `profile_state.dart` (each Cubit injects `IAnalyticsTracker` and tracks the screen-viewed event from its constructor)
   - `routing/app_router.dart` (`@TypedStatefulShellRoute<HomeShellRoute>` with `FeedRoute` + `ProfileRoute` typed branches; **no splash**)
   - `shared/theme/app_theme.dart` + `app_spacing.dart`
   - `l10n/app_en.arb`
6. Create the blueprint `test/` tree: `helpers/pump_app.dart`, `helpers/fakes.dart`, `smoke_test.dart`, `feature/home/feed_cubit_test.dart` (mocks `IAnalyticsTracker` with `mocktail` — anchors the convention for analytics-emitting Cubits).
7. Run `flutter pub get`.
8. Run `dart run build_runner build --delete-conflicting-outputs` to generate freezed, json_serializable, go_router, and (if enabled) drift files.
9. Run `dart analyze --fatal-infos --fatal-warnings` and `dart format --set-exit-if-changed .`. Report failures; do not auto-fix unless they are trivial formatting.
10. Emit the **manual Android flavor setup** note (edit `android/app/build.gradle.kts` — add `flavorDimensions`, `productFlavors { dev { ... } prod { ... } }` blocks, `applicationIdSuffix`s). Do not attempt to edit Gradle automatically; these edits are fragile.
11. Emit the **manual iOS scheme setup** note (Xcode → Duplicate Runner scheme as `dev` and `prod`, set `--flavor` via scheme args, configure per-flavor `Info.plist` display names). If Firebase is on, also remind about `flutterfire configure --project=<...>` and dropping per-flavor `google-services.json` / `GoogleService-Info.plist` — and call out that the `FirebaseAnalyticsTracker` already no-ops at runtime until then, so the app launches even before configure runs.

## Phase 3 — Post-init checklist

Print a concise checklist to the user, something like:

```
Scaffold complete. The app boots into a Material 3 Home shell with Feed + Profile
bottom-nav tabs. Each tab's Cubit fires its screen-viewed AnalyticsEvent on init
through the IAnalyticsTracker interface (Noop by default, Firebase under
INCLUDE_FIREBASE).

Next steps you need to do manually:

☐ Configure Android flavors in android/app/build.gradle.kts (see printed block).
☐ Configure iOS dev/prod schemes in Xcode (Product → Scheme → Manage Schemes).
☐ [if Firebase] run `flutterfire configure` for the dev flavor.
☐ [if Firebase] run `flutterfire configure` for the prod flavor.
   The FirebaseAnalyticsTracker no-ops at runtime until Firebase.apps.isNotEmpty,
   so the app launches without firebase_options.dart. Events flow as soon as
   configure has run + the per-flavor JSON/plist drops are in place.
☐ [if drift] set DATABASE_PASSPHRASE via flutter_secure_storage on first launch.
☐ Replace the Feed and Profile placeholders with your first real features
   (use `/new-feature <name>` or follow clean-architecture-flutter/SKILL.md).
☐ Add new analytics events as sealed entries in lib/core/analytics/analytics_event.dart
   (don't sprinkle magic strings — the sealed type is the source of truth).

Run it:
  flutter run --flavor dev  --target lib/main_dev.dart
  flutter run --flavor prod --target lib/main_prod.dart
```

## Ground rules

- **Stay inside the `ClaudeCodeMobile` workspace** unless the user explicitly points to a different parent directory.
- **No silent substitutions.** If a pinned version in the skill no longer resolves, surface the error and ask before bumping.
- **One command per Bash call where it matters** — keep `flutter create`, `flutter pub get`, and `build_runner` in separate visible calls so the user can see their output.
- **Never commit.** Leave the new app uncommitted; the user can review and commit themselves.
- **Do not scaffold real features** — `/init-flutter-app` stops once the Home shell with Feed + Profile tabs renders and `feed_cubit_test` passes. Use `/new-feature <name>` for actual product features.
- **Do not create files outside the new app** (no docs, no READMEs beyond the one `flutter create` provides). The user asked for a skeleton, not a documentation drop.

## When to say no

- If the target directory already contains a `pubspec.yaml`, stop. Ask whether to abort or scaffold into a subdirectory.
- If `flutter` is not on PATH or the version is older than 3.35, stop and tell the user.
- If the user picks options that conflict (e.g. "include drift" but Flutter can't resolve `sqlcipher_flutter_libs` on their platform), surface the error from `flutter pub get` verbatim and wait.
