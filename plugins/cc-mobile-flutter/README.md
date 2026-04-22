# cc-mobile-flutter

Opinionated Claude Code setup for Flutter apps — Clean Architecture, `flutter_bloc` + `bloc_concurrency`, `freezed` + `fpdart` (`Either<Failure, T>`), typed `go_router`, `get_it`, `dio` + OpenAPI client, `drift` + `sqlcipher`.

## What you get when you install

**Slash commands**

- `/init-flutter-app` — scaffold a brand-new Flutter app end-to-end (folders, `pubspec.yaml` via `dart pub add`, analysis options, core/ base classes, routing, tests, splash route). Asks about flavors, drift, Firebase, notifications, and workmanager up front.
- `/new-feature <name>` — scaffold a full feature (data + domain + presentation + module + route).
- `/add-screen <feature>/<Name>` — add a page + view + typed route.
- `/add-bloc <feature>/<Name>` — add a bloc (or cubit) with freezed states/events.
- `/add-usecase <feature>/<Name>` — add a domain use case.
- `/add-migration` — add a drift schema migration.
- `/fix-tests` — triage and repair broken tests.
- `/upgrade-deps` — walk through dependency upgrades safely.
- `/review-flutter` — delegate a review to the `flutter-reviewer` agent.

**Specialist agents**

- `flutter-architect` — architectural decisions, layer boundaries, state flow.
- `flutter-ui-engineer` — Compose-equivalent: screens, widgets, typed routes.
- `flutter-reviewer` — idiom + layer + bloc + async review (primary reviewer).
- `flutter-tester` — unit / bloc / widget / golden test design.
- `flutter-build-expert` — pubspec, build_runner, lints, flavors, CI.
- `flutter-performance-analyst` — frame budgets, jank, memory, build.
- `flutter-security-reviewer` — secrets, crypto, secure storage, SSL pinning.
- `flutter-a11y-reviewer` — accessibility semantics, focus order, contrast.
- `flutter-release-engineer` — versioning, signing, store uploads, staged rollouts.

**Skills** (auto-loaded by domain)

- `clean-architecture-flutter` — layer rules per feature.
- `dart-style` — idioms, nullability, naming.
- `widgets-and-screens` — Page / View split, state hoisting, previews.
- `bloc-state` — `bloc_concurrency`, freezed states, effects.
- `freezed-patterns` — unions, copyWith, exhaustive matching.
- `get-it-di` — per-feature modules + scopes (no `allowReassignment`).
- `dio-networking` — interceptors, auth refresh, error mapping via `ApiCallErrorHandling`.
- `openapi-generation` — generated API client, DTO boundaries.
- `drift-persistence` — tables, DAOs, migrations, `sqlcipher` setup.
- `localization-arb` — `l10n.yaml`, ARB files, pluralization.
- `firebase-services` — Crashlytics, Analytics, Remote Config.
- `flutter-testing` — `bloc_test` + `mocktail` + `alchemist`.
- `flutter-accessibility` — semantics, focus, large text.
- `flutter-security` — secure storage, key management, secrets hygiene.
- `flutter-performance` — `const` discipline, `RepaintBoundary`, `ListView.builder`.
- `flutter-app-skeleton` — the canonical blueprint `/init-flutter-app` drives.

## After installing

The plugin gives you skills, agents, and commands. It does **not** inject a `CLAUDE.md` into your project automatically. Drop the included `CLAUDE.md` at your project root so Claude Code loads the project context on open:

```bash
# from your project root
cp <plugin-source>/CLAUDE.md ./CLAUDE.md
```

(If you installed the `.plugin` via the UI, the plugin contents are unpacked under the Claude Code plugins directory — you can find the `CLAUDE.md` there and copy it.)

Edit the copy to reflect your app's specifics (app name, flavors, key feature folders). The template is meant as a starting point, not a lock-in.

## Updating

This plugin is built from the [ClaudeCodeMobile](https://github.com/) monorepo's `flutter/` subfolder. To pull an update:

1. Get the new `.plugin` file.
2. Reinstall (replaces the old version).

Your `CLAUDE.md` in the consuming project isn't touched by re-install — update it by hand when the template evolves.

## Building this plugin from source

From the `ClaudeCodeMobile/` repo root:

```bash
scripts/build-plugin.sh flutter
```

This reads `flutter/.claude/{skills,agents,commands}` + `flutter/CLAUDE.md` and re-packages them into `plugins/cc-mobile-flutter.plugin`. The hand-authored `plugin.json` and this README are preserved across rebuilds.

## Why these choices

See the [flutter/README.md](../../flutter/README.md) in the source repo for the full rationale (freezed vs Equatable, fpdart vs dartz, typed routes vs string enums, `bloc_concurrency` vs manual flags, `mocktail` only, GetIt scopes over `allowReassignment`).

## License

MIT.
