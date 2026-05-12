# Claude Code — Mobile setups

This folder holds per-stack Claude Code configurations. Each subfolder is a self-contained setup you can drop into (or start from, inside) a project of that stack.

## Stacks

- [`android/`](./android) — Kotlin + Jetpack Compose, MVVM + Clean Architecture, Hilt, Retrofit.
- [`ios/`](./ios) — Swift + SwiftUI, MVVM + Clean Architecture, `@Observable`, URLSession.
- [`kmm/`](./kmm) — Kotlin Multiplatform shared module (Ktor + Koin + shared ViewModels) consumed by native Compose/SwiftUI apps.
- [`flutter/`](./flutter) — Dart + Flutter, Clean Architecture, `flutter_bloc` + `bloc_concurrency`, `freezed` + `fpdart` (`Either<Failure, T>`), typed `go_router`, `get_it`, `dio` + OpenAPI client, `drift` + `sqlcipher`. Includes `/init-flutter-app` for scaffolding a new app end-to-end.

## Structure of each stack folder

```
<stack>/
├── CLAUDE.md               # Project context & conventions (stack-specific)
├── README.md               # Overview of the stack's setup
└── .claude/
    ├── settings.json       # Permissions, env
    ├── agents/             # Specialist subagents
    ├── skills/             # Domain knowledge packs (one per topic)
    └── commands/           # Slash commands
```

Claude Code picks up `CLAUDE.md` and everything under `.claude/` automatically when you open the folder.

Alongside the stack folders, the repo also ships a Claude Code plugin for each stack under [`plugins/`](./plugins) and a marketplace manifest at [`.claude-plugin/marketplace.json`](./.claude-plugin/marketplace.json). See [Distribution via marketplace](#distribution-via-marketplace).

## Using a stack

Option A — **install the plugin (recommended for teams).** Each stack ships as a Claude Code plugin via the `cc-mobile` marketplace. See [Distribution via marketplace](#distribution-via-marketplace) below. This gives you the skills, agents, and slash commands (including `/init-<stack>-app`) without copying files around.

Option B — **start a project here.** Initialize the project inside the corresponding subfolder, then open that subfolder in Claude Code. `/init-<stack>-app` will scaffold the whole app (folders, manifests, core/ base classes, routing, tests) with a few clarifying questions.

Option C — **bring your own project.** Copy the subfolder's `CLAUDE.md` and `.claude/` into the root of your existing project.

## Distribution via marketplace

This repo is itself a Claude Code plugin marketplace. `.claude-plugin/marketplace.json` at the repo root advertises the four stack plugins in [`plugins/`](./plugins).

**Coworkers install once:**

```text
/plugin marketplace add <git-url-of-this-repo>
/plugin install cc-mobile-android@cc-mobile
/plugin install cc-mobile-ios@cc-mobile
/plugin install cc-mobile-kmm@cc-mobile
/plugin install cc-mobile-flutter@cc-mobile
```

Installing just the stacks they work with is fine — they're independent.

### Working on a KMM project

KMM is the one stack that **needs three plugins together**: `cc-mobile-kmm` covers the shared module only, while the native UI lives in `androidApp/` (Compose) and `iosApp/` (SwiftUI). Install all three:

```text
/plugin install cc-mobile-kmm@cc-mobile
/plugin install cc-mobile-android@cc-mobile
/plugin install cc-mobile-ios@cc-mobile
```

A few things to know:

- **Use the KMM CLAUDE.md as your project root.** Copy `plugins/cc-mobile-kmm/CLAUDE.md` to your project root — it already references the `androidApp/` + `iosApp/` layout. The android and ios plugin CLAUDE.md files assume a standalone single-stack repo and will mislead the agent.
- **Slash commands are shared by name** (`/new-feature`, `/add-usecase`, `/add-migration`, `/fix-tests`, `/upgrade-deps`). When invoked unprefixed, Claude Code may pick any of the three. To target a specific stack, use the prefixed form: `/cc-mobile-kmm:new-feature`, `/cc-mobile-android:add-screen`, `/cc-mobile-ios:add-view`.
- **Pre-commit hooks are layout-aware.** The android plugin's hook skips itself when `:app` isn't a gradle module (it expects KMM's `:androidApp`). The ios plugin's hook skips itself when there's no `Package.swift` / `.xcodeproj` / `.xcworkspace` at the repo root. The kmm plugin's hook is the only one that runs in a KMM repo, gating commits on `:shared:allTests` and `:androidApp:lintDebug`.
- **Agent names never collide** — every agent is stack-prefixed (`kmm-reviewer`, `android-ui-engineer`, `ios-tester`). Pick the one that matches the file you're working on.

**Getting updates:**

```text
/plugin marketplace update cc-mobile
```

Re-running `install` on an updated plugin refreshes its skills, agents, and commands. The stack's `CLAUDE.md` is shipped inside the plugin; if a coworker has dropped a copy into their project root, they should re-copy it when the template evolves (see each plugin's README for the copy step).

**Publishing a new version:**

1. Edit the stack under `<stack>/.claude/` and `<stack>/CLAUDE.md` in this repo.
2. Bump `version` in the corresponding `plugins/cc-mobile-<stack>/.claude-plugin/plugin.json`.
3. Run `scripts/build-plugin.sh <stack>` (or `all`) to refresh `plugins/cc-mobile-<stack>/` and re-zip the `.plugin` artifact.
4. Commit and push. Coworkers pick up the change via `/plugin marketplace update`.

Hand-authored files (`plugin.json`, each plugin's `README.md`, and this repo's `marketplace.json`) are preserved across rebuilds — only `skills/`, `agents/`, `commands/`, and `CLAUDE.md` are refreshed from the source stack folder.

## Adding a new mobile stack later

Create a new sibling subfolder (e.g. `react-native/`) with the same skeleton:

```
<new-stack>/
├── CLAUDE.md
├── README.md
└── .claude/
    ├── settings.json
    ├── agents/
    ├── skills/
    └── commands/
```

Each stack has its own agents/skills/commands tailored to its conventions — don't try to share across stacks.

### A note on agent-role asymmetry

Every stack ships nine agents in the same pattern (`architect`, `ui-engineer` / `engineer`, `reviewer`, `tester`, `build-expert`, `performance-analyst`, `security-reviewer`, `a11y-reviewer`, `release-engineer`), with one deliberate exception: KMM's second slot is `kmm-engineer`, not `kmm-ui-engineer`. The KMM plugin covers the shared module only — the UI lives in the companion `cc-mobile-android` and `cc-mobile-ios` plugins — so `kmm-engineer` owns shared business logic, use cases, repositories, and shared ViewModels, and defers all rendering to the native-side UI engineers.

## Conventions shared across stacks

Where it's sensible, the four stacks align on the same concepts so you can move between them:

| Concept | Android | iOS | KMM (shared) | Flutter |
|---|---|---|---|---|
| Architecture | MVVM + Clean | MVVM + Clean | MVVM + Clean in `commonMain` | MVVM + Clean |
| State holder | `@HiltViewModel` + `StateFlow<UiState>` | `@Observable @MainActor` VM + `ViewState` | Shared `ViewModel()` + `StateFlow<UiState>` | `Bloc` / `Cubit` + freezed state |
| One-off events | `Channel<UiEvent>` | `AsyncStream<ViewEvent>` or callbacks | `Channel<UiEvent>` exposed as `Flow` | Effect field in state (or `Stream<Effect>`) |
| UI | Jetpack Compose | SwiftUI | Native per platform (Compose + SwiftUI) | Flutter widgets (Material 3) |
| DI | Hilt | Composition root + initializer injection | Koin (Hilt is Android-only) | `get_it` per-feature modules |
| Networking | Retrofit + OkHttp + kotlinx.serialization | URLSession + Codable | Ktor Client + kotlinx.serialization (OkHttp / Darwin engines) | `dio` + OpenAPI-generated client |
| Routing | Navigation-Compose | `NavigationStack` typed routes | N/A (per platform) | `go_router` typed routes |
| Error surface | sealed `Outcome<T>` carrying `DomainError` | sealed `DomainError` | sealed `DomainError` | sealed `Failure` + `Either<Failure, T>` (fpdart) |
| Persistence | Room + DataStore | SwiftData + `@AppStorage` + Keychain | SQLDelight (+ platform-specific KV via Koin) | drift + sqlcipher + SharedPrefs + secure storage |
| Testing | JUnit + MockK + Turbine | Swift Testing + hand-rolled fakes | `kotlin.test` + `kotlinx-coroutines-test` + MockEngine | `flutter_test` + `bloc_test` + `mocktail` + `alchemist` |
| Review agent | `android-reviewer` | `ios-reviewer` | `kmm-reviewer` | `flutter-reviewer` |
| Feature scaffolder | `/new-feature` | `/new-feature` | `/new-feature` | `/new-feature` |
| From-zero app scaffolder | `/init-android-app` | `/init-ios-app` | `/init-kmm-app` | `/init-flutter-app` |
| Flavors / Build variants | `productFlavors { dev, prod }` via `build.gradle.kts` | Xcode schemes `dev` / `prod` with per-scheme arg | `productFlavors` on `:androidApp` + Xcode schemes on `iosApp/` | `--flavor dev/prod` with `main_dev.dart` / `main_prod.dart` |
| Observability | Firebase Crashlytics + Analytics behind interfaces | MetricKit + Crashlytics behind interfaces | Platform Crashlytics injected via Koin | Firebase Crashlytics + Analytics behind interfaces |
| Analytics | Firebase Analytics (interfaced) | Firebase Analytics (interfaced) | Per platform, behind common interface | Firebase Analytics (interfaced) |
| Feature flags / Remote config | Firebase Remote Config | Firebase Remote Config | Per platform, behind common interface | Firebase Remote Config |
| CI | GitHub Actions: `./gradlew lint test assembleDebug` | GitHub Actions: `xcodebuild test` | GitHub Actions: `./gradlew :shared:allTests` + per-platform builds | GitHub Actions: `flutter analyze` + `flutter test` + `flutter build` |
| Lint / Format | ktlint + detekt | SwiftLint + SwiftFormat | ktlint + SwiftFormat | `dart analyze --fatal-infos --fatal-warnings` + `dart format` |
