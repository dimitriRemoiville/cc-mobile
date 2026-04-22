---
description: Scaffold a fresh Kotlin Multiplatform Mobile project — :shared with commonMain/androidMain/iosMain, :androidApp (Compose), iosApp/ (SwiftUI), Ktor Client, kotlinx.serialization, Koin DI, StateFlow + Channel view models, optional SQLDelight.
argument-hint: "[package_id]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task, AskUserQuestion
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

Read `.claude/skills/kmm-app-skeleton/SKILL.md` in full. Source of truth for every file.

Placeholders: `{{APP_NAME}}`, `{{PACKAGE_ID}}`, `{{PACKAGE_PATH}}`, `{{APP_DISPLAY_NAME}}`, `{{IOS_MIN}}`.

Flags: `INCLUDE_SQLDELIGHT`, `INCLUDE_FIREBASE`, `IOS_DIST_DIRECT` / `IOS_DIST_COCOAPODS` / `IOS_DIST_SPM`.

## Phase 2 — Execute the scaffold

Follow the skill's procedure:

1. Create `{{APP_NAME}}/` directory with Gradle wrapper.
2. Write `settings.gradle.kts`, root `build.gradle.kts`, `gradle.properties`, and `gradle/libs.versions.toml`. Use the skill as the **shape** of `libs.versions.toml` (which refs, which aliases) — do **not** copy the skill's placeholder version strings. Resolve each ref to the latest stable (non-alpha, non-RC) at scaffold time, then verify every resolved version against the skill's floor-constraint table. Stop and report if any fall below a floor.
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
- User picks CocoaPods but `pod` is not on PATH → fall back to direct mode and tell the user.
