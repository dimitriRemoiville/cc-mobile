---
description: Scaffold a fresh Android app with this project's conventions — Kotlin, Compose, Clean Architecture, Hilt, Retrofit, Coroutines/Flow, Navigation Compose with typed routes, Material 3.
argument-hint: "[package_id]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task, AskUserQuestion
---

# /init-android-app

You are scaffolding a brand-new Android application from scratch. **Nothing is generated until Phase 0 is answered** — flags materially change the generated files.

## Phase 0 — Gather inputs

Use `AskUserQuestion` to collect (propose defaults, let user confirm or override in one round-trip):

1. **App display name** (free-text, e.g. "My App").
2. **Application id / package id** (reverse-DNS, e.g. `com.example.myapp`). If `$ARGUMENTS` is provided, use as default.
3. **Min SDK** (default 26) / **Target & Compile SDK** (default latest stable — surface the current value).
4. **Include Room persistence?** (yes/no) — drives `INCLUDE_ROOM`.
5. **Include DataStore?** (yes/no, default yes) — drives `INCLUDE_DATASTORE`.
6. **Include Firebase (Crashlytics + Analytics)?** (yes/no) — drives `INCLUDE_FIREBASE`. Warn: requires manual `google-services.json` drop per-flavor.
7. **Flavors**: `dev` + `prod` (default yes). If yes, drives flavor blocks in Gradle.

Confirm the plan in one short paragraph. Proceed only after confirmation.

## Phase 1 — Load the blueprint

Read `.claude/skills/android-app-skeleton/SKILL.md` in full. It is the source of truth for:

- The execution order.
- Every file template (`build.gradle.kts`, `libs.versions.toml`, `AndroidManifest.xml`, source files under `app/src/main/java`, tests under `app/src/test/java`).
- Placeholders: `{{APP_NAME}}`, `{{APP_CLASS}}`, `{{PACKAGE_ID}}`, `{{PACKAGE_PATH}}`, `{{APP_DISPLAY_NAME}}`.
- Flag blocks: `INCLUDE_ROOM`, `INCLUDE_DATASTORE`, `INCLUDE_FIREBASE`.
- Hard rules (no `kapt` — KSP only; no string routes; no `android.*` imports inside the `domain` package; Compose BOM — never pin Compose libs individually).

Do not improvise file contents. Substitute placeholders.

## Phase 2 — Execute the scaffold

Follow the skill's procedure:

1. Create the project directory and the Gradle structure:
   - Root: `settings.gradle.kts`, `build.gradle.kts`, `gradle.properties`, `gradle/libs.versions.toml`, `gradle/wrapper/gradle-wrapper.properties`.
   - Single module: `:app` only. Clean Architecture layers live as packages (`domain/`, `data/`, `ui/`), not as separate Gradle modules — see the skill's "Module or package?" note. Extract modules later if the app grows into multi-feature territory or a shared library appears.
2. Initialize the Gradle wrapper: `gradle wrapper --gradle-version <latest-stable>` (if `gradle` is on PATH), or copy in a known-good `gradle-wrapper.jar` + `gradlew` + `gradlew.bat` from a local cache. Bail if neither is available.
3. Write `libs.versions.toml` using the skill as the **shape** (which refs to include, which libraries/plugins to alias): AGP, Kotlin, KSP, Compose BOM, Hilt, Retrofit, OkHttp, Coroutines, Navigation Compose, JUnit, MockK, Turbine; plus Room / DataStore / Firebase if flagged. Do **not** copy the skill's placeholder version strings — resolve each ref to the latest stable (non-alpha, non-RC) at scaffold time, then verify every resolved version against the skill's floor-constraint table. Stop and report if any fall below a floor. KSP must match the resolved Kotlin patch version (`<kotlin>-<ksp-patch>`).
4. Write root `build.gradle.kts` and `settings.gradle.kts` (the latter includes `:app` only).
5. Write `app/build.gradle.kts` with all runtime deps (Compose BOM, Hilt, Navigation Compose, Retrofit + OkHttp + kotlinx-serialization, Coroutines, plus Room / DataStore / Firebase under their flags). No `project(":core:*")` entries.
6. Write `AndroidManifest.xml`, `strings.xml`, themes, one launcher icon set (mipmap-anydpi-v26 vector placeholder).
7. Write source files under `app/src/main/java/{{PACKAGE_PATH}}/`:
   - `{{APP_CLASS}}.kt` (Hilt Application), `MainActivity.kt`.
   - `ui/theme/` (Material 3), `ui/splash/SplashScreen.kt` + `SplashViewModel.kt`, `navigation/AppNavGraph.kt` (typed `@Serializable` destinations).
   - `domain/` — `Outcome.kt` sealed, `DomainError.kt`, one sample use case interface. Treat this package as Android-free by convention — no `android.*` imports here, ever.
   - `data/network/` — `ApiClientFactory.kt` (Retrofit + OkHttp logging), `RemoteDataSource.kt` placeholder.
   - `data/di/` — Hilt `@Module` providing Retrofit + OkHttp + Json.
   - (Conditional) `data/persistence/` — Room DB, entities, DAOs, repository.
   - (Conditional) `data/datastore/` — DataStore typed preferences.
   - (Conditional) Firebase init in the Application class + gitignored `google-services.json` reminder.
8. Write one ViewModel test (`SplashViewModelTest.kt`) under `app/src/test/java/{{PACKAGE_PATH}}/ui/splash/` using JUnit 4 + MockK + Turbine.
9. Run `./gradlew :app:compileDebugKotlin` to validate. If it fails, print the error and stop.
10. Run `./gradlew :app:testDebugUnitTest`.
11. Print the manual setup note — signing config (`signingConfigs.release`), per-flavor `applicationIdSuffix`, CI, Play Console metadata, and "extract `domain/` + `data/` to `:core:*` modules once you have real coupling pressure" as a followup.

## Phase 3 — Post-init checklist

Print a concise checklist:

```
Scaffold complete. Next steps:

☐ Add release signing config in app/build.gradle.kts (keystore path, alias, passwords via gradle.properties or env).
☐ [if Firebase] drop dev + prod google-services.json into app/src/<flavor>/ and verify via `./gradlew :app:processDevDebugGoogleServices`.
☐ [if Room] run `./gradlew :app:kspDebugKotlin` — confirm schemas/ directory is populated.
☐ Replace the splash screen placeholder with your first real feature.

Build it:
  ./gradlew :app:installDevDebug
  ./gradlew :app:testDebugUnitTest
```

## Ground rules

- Stay inside the `ClaudeCodeMobile` workspace unless the user points to a different parent directory.
- One command per Bash call where it matters (`gradle wrapper`, `./gradlew compileDebugKotlin`, `./gradlew testDebugUnitTest`).
- Never commit.
- Do not scaffold features — stop at a runnable splash.
- Do not create unsolicited docs.

## When to say no

- Target dir already contains `settings.gradle.kts` → ask whether to abort or scaffold into a subdirectory.
- `java`, `gradle`, or Android SDK not on PATH → stop and tell the user.
- User picks Firebase without having a project set up → proceed but flag the manual `google-services.json` drop loudly.
