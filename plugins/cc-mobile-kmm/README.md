# cc-mobile-kmm

Opinionated Claude Code setup for Kotlin Multiplatform Mobile — a shared module with MVVM + Clean Architecture in `commonMain`, consumed by native Compose (Android) and SwiftUI (iOS) apps. Ktor Client + kotlinx.serialization, Koin DI, shared `ViewModel()` exposing `StateFlow<UiState>`, SQLDelight, multiplatform-settings.

## What you get when you install

**Slash commands**

- `/init-kmm-app` — scaffold a brand-new KMM shared module (`commonMain` skeleton, Gradle wiring, Koin modules, SQLDelight setup, XCFramework output for iOS).
- `/new-feature <name>` — scaffold a full feature in `commonMain` (data + domain + presentation with a shared ViewModel).
- `/add-viewmodel <feature>/<Name>` — add a shared `ViewModel` with `StateFlow<UiState>` and a `Channel<UiEvent>` exposed as Flow.
- `/add-usecase <feature>/<Name>` — add a domain use case in `commonMain`.
- `/add-migration` — add a SQLDelight schema migration.
- `/fix-tests` — triage and repair broken tests.
- `/upgrade-deps` — walk through dependency upgrades safely across commonMain and platform sourcesets.
- `/review-kmm` — delegate a review to the `kmm-reviewer` agent.

**Specialist agents**

- `kmm-architect` — `commonMain` vs platform boundaries, `expect`/`actual` discipline, shared-VM contracts.
- `kmm-engineer` — implement features across `commonMain` + `androidMain` + `iosMain`.
- `kmm-reviewer` — idiom + layer + sourceset + concurrency review (primary reviewer).
- `kmm-tester` — `kotlin.test` + `kotlinx-coroutines-test` + Ktor `MockEngine`.
- `kmm-build-expert` — multiplatform Gradle, version catalogs, XCFramework, CocoaPods vs SPM.
- `kmm-performance-analyst` — shared-code cost, serialization, frame budgets on both sides.
- `kmm-security-reviewer` — secrets, crypto, platform keystores, certificate pinning in Ktor.
- `kmm-a11y-reviewer` — accessibility concerns that surface from shared code.
- `kmm-release-engineer` — XCFramework publishing, CocoaPods podspec, Maven artifacts, versioning.

**Skills** (auto-loaded by domain)

- `kmm-architecture` — `commonMain` + `androidMain` + `iosMain` layering, `expect`/`actual` rules.
- `ktor-multiplatform` — Ktor Client setup, engines (OkHttp / Darwin), interceptors, error mapping.
- `kotlinx-serialization` — `@Serializable` DTOs, polymorphism, custom serializers.
- `koin-di` — platform modules, `KoinComponent`, testing.
- `shared-viewmodels` — `ViewModel()` abstraction, `StateFlow<UiState>`, `Channel<UiEvent>`.
- `sqldelight-persistence` — schemas, generated queries, migrations, tests.
- `multiplatform-settings` — the multiplatform KV preference wrapper; platform-specific backing via Koin.
- `ios-interop` — how iOS consumes shared code; suspend/Flow bridging, nullability, `@Throws`.
- `xcframework-distribution` — building + publishing XCFramework; SPM and CocoaPods distribution.
- `kmm-testing` — common tests + platform tests + `MockEngine` + coroutine-time tests.
- `kmm-app-skeleton` — canonical blueprint `/init-kmm-app` drives.

## After installing

The plugin ships skills, agents, and commands. It does **not** inject a `CLAUDE.md` into your project automatically. Drop the included `CLAUDE.md` at your shared-module root so Claude Code loads the project context on open:

```bash
# from your KMM repo root
cp <plugin-source>/CLAUDE.md ./CLAUDE.md
```

Edit the copy to reflect your app's specifics (module names, platforms targeted, XCFramework output path).

## Updating

When a new `.plugin` (or marketplace version) ships, reinstall. Your project's `CLAUDE.md` isn't touched by re-install — update it by hand when the template evolves.

## Building this plugin from source

From the `ClaudeCodeMobile/` repo root:

```bash
scripts/build-plugin.sh kmm
```

The script reads `kmm/.claude/{skills,agents,commands}` + `kmm/CLAUDE.md` and re-packages them. The hand-authored `plugin.json` and this README are preserved across rebuilds.

## Why these choices

See [kmm/README.md](../../kmm/README.md) in the source repo for the rationale (Koin over Kodein, Ktor over Apollo-style clients, SQLDelight over Realm/Exposed, shared ViewModels over iOS-only state holders, XCFramework over Kotlin/Native-direct SPM).

## Companion apps

This plugin covers the shared module only. If you're also wiring native Compose and SwiftUI apps, install [cc-mobile-android](../cc-mobile-android) and [cc-mobile-ios](../cc-mobile-ios) for the native-side conventions.

## License

MIT.
