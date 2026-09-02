---
description: Scaffold a fresh Kotlin Multiplatform Mobile project — :shared with commonMain/androidMain/iosMain, :androidApp (Compose), iosApp/ (SwiftUI), Ktor Client, kotlinx.serialization, Koin DI, StateFlow + Channel view models, optional SQLDelight.
argument-hint: "[package_id]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task, AskUserQuestion, WebFetch
---

# /init-kmm-app

You are scaffolding a brand-new KMM project from scratch. **Nothing is generated until Phase 0 is answered** — flags materially change the generated files.

## Phase 0 — Gather inputs

Use `AskUserQuestion` (propose defaults, one round-trip):

1. **App display name** (free-text, e.g. "My App").
2. **Base package id** (reverse-DNS, e.g. `com.example.myapp`). If `$ARGUMENTS` is provided, use as default.
3. **iOS framework distribution**: `direct embedding` (default, uses `embedAndSignAppleFrameworkForXcode`) or `CocoaPods` or `SPM / XCFramework`.
4. **Include SQLDelight persistence?** (yes/no) — drives `INCLUDE_SQLDELIGHT`.
5. **Include Firebase (per-platform Crashlytics/Analytics behind a common interface)?** (yes/no) — drives `INCLUDE_FIREBASE`.
6. **Min iOS deployment** (default 18.0) and **Android min SDK** (default 26).

Confirm the plan in one short paragraph. Proceed only after confirmation.

## Phase 1 — Load the blueprint

Read `${CLAUDE_PLUGIN_ROOT}/skills/kmm-app-skeleton/SKILL.md` in full. Source of truth for every file.

Placeholders: `{{APP_NAME}}`, `{{PACKAGE_ID}}`, `{{PACKAGE_PATH}}`, `{{APP_DISPLAY_NAME}}`, `{{IOS_MIN}}`.

Flags: `INCLUDE_SQLDELIGHT`, `INCLUDE_FIREBASE`, `IOS_DIST_DIRECT` / `IOS_DIST_COCOAPODS` / `IOS_DIST_SPM`.

## Phase 1.5 — Resolve all versions online

The skill's `[versions]` block is intentionally placeholder-only (`<latest-stable>`). Every ref is resolved at scaffold time by reading the registry's `maven-metadata.xml` for Gradle/JVM deps, and the GitHub Releases API for the iOS-side SPM/CocoaPods deps — that's why this command keeps working months from now without skill edits when libraries cut new releases.

For each Maven ref, `WebFetch` the URL below and pick the newest version that is **not** suffixed `-alpha`, `-beta`, `-RC`, `-rc`, `-dev`, `-SNAPSHOT`, `-eap`, `-Beta`, or `-M[0-9]`. The interesting node is `<versioning><release>` (preferred) or the last `<version>` under `<versions>` after pre-release filtering.

### Gradle / JVM refs

| Ref | URL |
|---|---|
| `agp` | `https://dl.google.com/android/maven2/com/android/tools/build/gradle/maven-metadata.xml` |
| `kotlin` | `https://repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib/maven-metadata.xml` |
| `coroutines` | `https://repo1.maven.org/maven2/org/jetbrains/kotlinx/kotlinx-coroutines-core/maven-metadata.xml` |
| `serialization` (kotlinx-serialization-json) | `https://repo1.maven.org/maven2/org/jetbrains/kotlinx/kotlinx-serialization-json/maven-metadata.xml` |
| `ktor` | `https://repo1.maven.org/maven2/io/ktor/ktor-client-core/maven-metadata.xml` |
| `koin` | `https://repo1.maven.org/maven2/io/insert-koin/koin-core/maven-metadata.xml` (use the same value for `koin-android` and `koin-androidx-compose` — the multi-artifact release ships them in lockstep) |
| `sqldelight` (only if `INCLUDE_SQLDELIGHT`) | `https://repo1.maven.org/maven2/app/cash/sqldelight/runtime/maven-metadata.xml` |
| `multiplatform-settings` | `https://repo1.maven.org/maven2/com/russhwolf/multiplatform-settings/maven-metadata.xml` |
| `compose-bom` | `https://dl.google.com/android/maven2/androidx/compose/compose-bom/maven-metadata.xml` |
| `activity-compose` | `https://dl.google.com/android/maven2/androidx/activity/activity-compose/maven-metadata.xml` |
| `lifecycle` | `https://dl.google.com/android/maven2/androidx/lifecycle/lifecycle-runtime-ktx/maven-metadata.xml` |
| `junit` | `https://repo1.maven.org/maven2/junit/junit/maven-metadata.xml` |
| `compileSdk` / `targetSdk` (`:androidApp`) | Use the latest stable Android API level. Run `ls $ANDROID_HOME/platforms` and pick the highest `android-N`. Hard-code that integer in `androidApp/build.gradle.kts`. |

**Resolution order matters.** Resolve `kotlin` *before* `coroutines` and `serialization` (both ship aligned with a Kotlin version). KMM also requires `kotlin >= 2.0.0` for the K2 compiler; if the resolved value is below 2.0, stop — the skeleton's idioms (the new `androidTarget()` DSL, `actual typealias` placement, kotlinx-coroutines-core 1.8+ multiplatform layout) all assume K2.

### iOS-side refs

| Flag | Ref | URL |
|---|---|---|
| `INCLUDE_FIREBASE` (any iOS dist mode) | `firebase-ios-sdk` | `https://api.github.com/repos/firebase/firebase-ios-sdk/releases/latest` — read `tag_name`, filter out `-alpha`/`-beta`/`-rc`. Use this in the iOS-side dependency declaration (Podfile, `Package.swift`, or the XCFramework consumer manifest depending on `IOS_DIST_*`). |
| `IOS_DIST_COCOAPODS` | CocoaPods CLI | Verify `pod --version` locally — the skeleton's `Podfile` syntax assumes CocoaPods 1.13+. If older, stop and ask the user to upgrade `gem install cocoapods` rather than rewriting the Podfile. |

If a GitHub fetch rate-limits (HTTP 403 with `X-RateLimit-Remaining: 0`), fall back to `git ls-remote --tags https://github.com/firebase/firebase-ios-sdk` (Bash) and pick the highest semver tag. Stop and surface the failure if both routes fail.

### Sanity-check

After resolution, sanity-check against the skill's "Compatibility traps" table. Known traps: AGP 9 + Kotlin < 2.2, Ktor 3.x + kotlinx-coroutines < 1.8, SQLDelight 2.x + Kotlin < 2.0. If a trap pattern matches, bump the affected ref to the next available version that clears it and rerun the affected fetch. Do not silently downgrade.

**Do not fall back to hard-coded defaults if a fetch fails.** Stop and surface the failure (network down, registry returning HTML, version filter empty after stripping pre-releases) — proceeding with stale numbers is exactly the failure mode this phase is meant to prevent.

**Resolution output.** Before Phase 2, print the resolved version table so the user can sanity-check it. Example:

```
Resolved versions:
  agp             = 9.0.2
  kotlin          = 2.2.10
  coroutines      = 1.10.1
  serialization   = 1.7.5
  ktor            = 3.0.3
  koin            = 4.0.0
  multiplatform-settings = 1.2.0
  compose-bom     = 2025.01.00
  activity-compose= 1.10.0
  compileSdk      = 36
  firebase-ios    = 11.6.0    (INCLUDE_FIREBASE=on)
```

## Phase 2 — Execute the scaffold

Follow the skill's procedure:

1. Create `{{APP_NAME}}/` directory with Gradle wrapper.
2. Write `settings.gradle.kts`, root `build.gradle.kts`, `gradle.properties`, and `gradle/libs.versions.toml` using the skill as the **shape** (which refs to include, which libraries/plugins to alias). All version values come from Phase 1.5's resolution table — never copy the skill's `<latest-stable>` placeholders verbatim, never invent numbers from training data. After resolution, sanity-check the set against the skill's "Compatibility traps" table. Stop and report if any resolved value falls below a documented floor.
3. Write `:shared` (`build.gradle.kts`, `src/commonMain/`, `src/androidMain/`, `src/iosMain/`, `src/commonTest/`). Contents:
   - `:shared/commonMain` — `Outcome`, `DomainError`, `KtorClientFactory`, `SampleApi`, `SampleRepository`, `SampleViewModel` with `StateFlow<UiState>` + `Channel<UiEvent>`, Koin module for common deps.
   - `:shared/androidMain` — Android Ktor engine, Android Koin module providing `Context`-bound bits (SQLDelight driver, multiplatform-settings).
   - `:shared/iosMain` — Darwin Ktor engine, iOS Koin module.
   - `:shared/commonTest` — one test wiring MockEngine + repository.
4. Write `:androidApp` (Compose):
   - `MainActivity`, `MainApplication` (calls `initKoin` + any platform adapters), `ui/splash/SplashScreen.kt`, theme.
5. Write `iosApp/` (SwiftUI):
   - Xcode-friendly directory with `{{APP_NAME}}App.swift`, `SplashView.swift`, `KoinIOS.swift` bootstrap.
   - (If `IOS_DIST_DIRECT`) add the `embedAndSignAppleFrameworkForXcode` run-script reference in the Xcode project.
   - (If `IOS_DIST_COCOAPODS`) emit a `Podfile` and run `pod install` guidance.
   - (If `IOS_DIST_SPM`) emit the XCFramework packaging Gradle task.
6. Write tests (`:shared/commonTest/.../SampleRepositoryTest.kt`).
7. Run `./gradlew :shared:jvmTest` and `./gradlew :androidApp:assembleDebug`.
8. Run `./gradlew :shared:linkPodDebugFrameworkIosSimulatorArm64` (CocoaPods mode) or `./gradlew :shared:embedAndSignAppleFrameworkForXcode -Pkotlin.native.cocoapods.platform=iphonesimulator` (direct mode).
9. Emit the manual setup note — Xcode signing, framework search paths, scheme config for dev/prod.

## Phase 3 — Post-init checklist

Print:

```
Scaffold complete. Next steps:

☐ [iOS] Open iosApp/{{APP_NAME}}.xcodeproj, set the team, add build phases if not done.
☐ [iOS, direct mode] verify the "Embed Framework" run script runs before the Copy Bundle Resources phase.
☐ [iOS, CocoaPods mode] cd iosApp && pod install.
☐ [SQLDelight] review the schema in shared/src/commonMain/sqldelight/ and commit the <initial>.db snapshot.
☐ Replace the splash screen on both platforms with your first real feature.

Build it:
  ./gradlew :androidApp:assembleDebug
  ./gradlew :shared:allTests
  (Xcode) ⌘R on the iosApp scheme
```

## Ground rules

- Stay inside the `ClaudeCodeMobile` workspace unless the user points elsewhere.
- One command per Bash call where it matters.
- Never commit.
- Stop at a runnable splash on both platforms.
- Do not scaffold features.

## When to say no

- Target dir already contains `settings.gradle.kts` or `iosApp/` → ask whether to abort or scaffold into a subdirectory.
- `java`, `gradle`, `xcodebuild` (or Xcode tooling) missing → stop.
- Phase 1.5 resolves `kotlin` < 2.0 → stop (the skeleton's K2 idioms won't compile).
- Phase 1.5 Maven fetch fails AND no offline cache available → stop. Don't invent versions from training data.
- User picks CocoaPods but `pod` is not on PATH → fall back to direct mode and tell the user.
- User picks CocoaPods + Firebase but local `pod --version` < 1.13 → stop (Phase 1.5).
