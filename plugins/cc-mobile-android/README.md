# cc-mobile-android

Opinionated Claude Code setup for Android apps — Kotlin + Jetpack Compose, MVVM + Clean Architecture, Hilt DI, Retrofit + OkHttp + kotlinx.serialization, Room + DataStore, Navigation-Compose.

## What you get when you install

**Slash commands**

- `/init-android-app` — scaffold a brand-new Android app end-to-end (Gradle modules, dependencies, core/ base classes, navigation, Hilt, tests).
- `/new-feature <name>` — scaffold a full feature (data + domain + presentation + DI module + nav destination).
- `/add-screen <feature>/<Name>` — add a Compose screen + ViewModel + nav route.
- `/add-usecase <feature>/<Name>` — add a domain use case.
- `/add-migration` — add a Room schema migration.
- `/fix-tests` — triage and repair broken tests.
- `/upgrade-deps` — walk through dependency upgrades safely.
- `/review-android` — delegate a review to the `android-reviewer` agent.

**Specialist agents**

- `android-architect` — architectural decisions, layer boundaries, state flow.
- `android-ui-engineer` — Compose screens, widgets, Navigation-Compose.
- `android-reviewer` — idiom + layer + state + coroutines review (primary reviewer).
- `android-tester` — unit / ViewModel / Compose / instrumentation test design.
- `android-build-expert` — Gradle, version catalogs, build variants, CI.
- `android-performance-analyst` — frame budgets, jank, memory, Baseline Profiles.
- `android-security-reviewer` — secrets, crypto, secure storage, network security config.
- `android-a11y-reviewer` — accessibility semantics, TalkBack, large text.
- `android-release-engineer` — versioning, signing, Play Console uploads, staged rollouts.

**Skills** (auto-loaded by domain)

- `android-architecture` — layer rules per feature.
- `kotlin-style` — naming, nullability, coroutines, Flow, scope functions.
- `compose-ui` — Material 3, state hoisting, recomposition, previews, accessibility.
- `navigation-compose` — typed destinations, arguments, deep links.
- `hilt-di` — modules, ViewModel injection, tests.
- `retrofit-networking` — service interfaces, interceptors, error mapping, DTO boundaries.
- `room-persistence` — entities, DAOs, migrations, test strategies.
- `datastore-preferences` — Preferences vs Proto DataStore, migration from SharedPreferences.
- `android-testing` — JUnit + MockK + Turbine + Compose UI tests + Hilt-aware instrumentation.
- `android-accessibility` — semantics, focus, contentDescription, contrast.
- `android-security` — Keystore, EncryptedSharedPreferences, SSL pinning, R8 rules.
- `android-performance` — Baseline Profiles, `remember` discipline, `LazyColumn` keys.
- `android-app-skeleton` — canonical blueprint `/init-android-app` drives.

## After installing

The plugin ships skills, agents, and commands. It does **not** inject a `CLAUDE.md` into your project automatically. Drop the included `CLAUDE.md` at your project root so Claude Code loads the project context on open:

```bash
# from your project root
cp <plugin-source>/CLAUDE.md ./CLAUDE.md
```

Edit the copy to reflect your app's specifics. The template is a starting point, not a lock-in.

## Updating

When a new `.plugin` (or marketplace version) ships, reinstall. Your project's `CLAUDE.md` isn't touched by re-install — update it by hand when the template evolves.

## Building this plugin from source

From the `ClaudeCodeMobile/` repo root:

```bash
scripts/build-plugin.sh android
```

The script reads `android/.claude/{skills,agents,commands}` + `android/CLAUDE.md` and re-packages them. The hand-authored `plugin.json` and this README are preserved across rebuilds.

## Why these choices

See [android/README.md](../../android/README.md) in the source repo for the rationale behind the stack picks (Compose-first, Hilt over manual DI, kotlinx.serialization over Moshi/Gson, Room over SQLDelight on Android, Turbine for Flow testing).

## License

MIT.
