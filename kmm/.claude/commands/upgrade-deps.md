---
description: Upgrade KMP dependencies from the Gradle version catalog with a dry-run diff before applying. Self-sufficient — walks Maven metadata directly, no Gradle plugin required. Flags iOS-side (SwiftPM / CocoaPods) as a separate manual pass.
argument-hint: "[--dry-run | --apply] [--group=kotlin|ktor|coroutines|serialization|sqldelight|koin|compose-multiplatform|androidx]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task, WebFetch
---

# /upgrade-deps

Upgrade dependencies declared in `gradle/libs.versions.toml` (the Gradle side — shared module + Android app), then surface the iOS-side updates separately (SwiftPM / CocoaPods) for the user to apply manually. Resolution is done by walking each ref's `maven-metadata.xml` directly so this command works on a freshly-scaffolded project with no extra Gradle plugins.

## Steps

1. Locate `gradle/libs.versions.toml`. Bail if it doesn't exist (this command requires a version catalog; hand off to `kmm-build-expert` if the project predates one).

2. **Resolve the latest stable for each `[versions]` ref by `WebFetch`-ing its `maven-metadata.xml`** (reuse the URL table from `.claude/commands/init-kmm-app.md` Phase 1.5 if present; otherwise the canonical sources are):
   - **Kotlin / KSP / coroutines / serialization / kotlin-test:** Maven Central, e.g. `https://repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib/maven-metadata.xml`.
   - **AGP:** `https://dl.google.com/dl/android/maven2/com/android/tools/build/gradle/maven-metadata.xml`.
   - **AndroidX (`:androidApp` side):** `https://dl.google.com/dl/android/maven2/androidx/<group>/<artifact>/maven-metadata.xml`.
   - **Compose Multiplatform (JetBrains):** `https://maven.pkg.jetbrains.space/public/p/compose/dev/org/jetbrains/compose/compose-gradle-plugin/maven-metadata.xml`, with a fallback to Maven Central at `https://repo1.maven.org/maven2/org/jetbrains/compose/compose-gradle-plugin/maven-metadata.xml`. **This is a separate version from AGP's Compose Compiler plugin** — KMP projects that share UI use the JetBrains Compose Multiplatform ref, not the Android-only `androidx.compose` ref.
   - **Ktor:** `https://repo1.maven.org/maven2/io/ktor/ktor-client-core/maven-metadata.xml`.
   - **SQLDelight:** `https://repo1.maven.org/maven2/app/cash/sqldelight/runtime/maven-metadata.xml`.
   - **Koin:** `https://repo1.maven.org/maven2/io/insert-koin/koin-core/maven-metadata.xml`.
   - **multiplatform-settings:** `https://repo1.maven.org/maven2/com/russhwolf/multiplatform-settings/maven-metadata.xml`.

   Filter out any `-alpha`, `-beta`, `-RC`, `-rc`, `-dev`, `-SNAPSHOT`, `-eap`, `-M[0-9]+` suffixes. For `ksp`, filter to versions starting with the resolved Kotlin version (KSP is `<kotlinVersion>-<kspPatch>`).

   - **Optional speedup:** if the project ships `com.github.ben-manes.versions` (the Ben-Manes "gradle-versions-plugin"), `./gradlew dependencyUpdates -DoutputFormatter=plain -Drevision=release` is a useful hint — but still verify with `maven-metadata.xml` because the plugin can be a release behind.

3. Build a proposed diff for `libs.versions.toml`:
   - Only bump within the major currently in use **unless** `--group=...` explicitly targets a major bump.
   - Skip any version line that has a trailing `# pin: <reason>` comment.
   - Group by area in the output: Kotlin / KSP / coroutines / serialization, AGP + AndroidX, Compose Multiplatform, Ktor, SQLDelight, Koin, multiplatform-settings, testing, other.

4. **Sanity-check against the skeleton's "Compatibility traps" table** (`.claude/skills/kmm-app-skeleton/SKILL.md` → "Compatibility traps" if it exists). KMP-specific bundles that move together:
   - **Kotlin + KSP + Compose Multiplatform + coroutines + serialization** — bumping Kotlin almost always requires bumping KSP (matching `<kotlin>-1.0.<n>`) and Compose Multiplatform's Kotlin compatibility. Bundle these or refuse.
   - **Ktor + kotlinx-coroutines + kotlinx-serialization** — Ktor's published version is built against specific versions of both; mismatches surface at iOS link time, not at JVM test time.
   - **SQLDelight major bumps** — sometimes require regenerating `.sq` code-gen output and adjusting type-converter signatures. Warn the user.
   - **Koin 3.x → 4.x** — breaking changes to `startKoin` and module DSL. Refuse unless `--group=koin` is explicit.

   If a proposed bump would land in a known trap, surface it in the diff and pick the next compatible version (or refuse and ask).

5. **Dry-run (default)**: print the proposed `toml` diff to the user. Stop. Ask: "Apply?"

6. **Apply** (`--apply`):
   - Write the new `toml`.
   - Run `./gradlew :shared:dependencies` to validate Kotlin/native dependency resolution across source sets.
   - Run `./gradlew :shared:check :androidApp:assembleDebug` — this catches plugin-shape regressions (missing Compose Multiplatform compiler plugin, mismatched KSP version, broken Ktor engine wiring) and runs the shared module's commonTest + JVM tests.
   - If anything fails, **revert the `toml`** and surface the error. Do not leave the repo in a broken state.
   - **iOS side is NOT auto-validated.** `./gradlew :shared:linkPodDebugFrameworkIosSimulatorArm64` would catch native link errors but doubles the runtime; `xcodebuild test` requires a simulator. Flag the user: "Re-run `xcodebuild test` against `iosApp/` to verify iOS-side after the bump."

7. **iOS-side dependency pass (separate from the catalog).** Surface, do not auto-bump:
   - **SwiftPM:** parse `iosApp/Package.swift` (or `iosApp/Project.swift` for Tuist) for remote packages, then `WebFetch` `https://api.github.com/repos/<owner>/<repo>/releases/latest` (or `/tags`) per package to surface the latest stable. Print a SwiftPM-style diff and recommend the user run `xcodebuild -resolvePackageDependencies` after editing.
   - **CocoaPods** (if `iosApp/Podfile` exists): `cd iosApp && pod outdated` and surface the output. Recommend `pod update <PodName>` per pod — never `pod update` globally on autopilot.
   - **Don't try to unify SwiftPM/CocoaPods versions with the Gradle catalog.** They're separate ecosystems with different release cadences; pretending they're one breaks the next person who reads the diff.

8. Summarize:
   - **Gradle (catalog):** bumped versions by group (old → new), skipped (pinned, pre-release, trap-blocked), post-bump checks (`:shared:check`, `:androidApp:assembleDebug` results).
   - **iOS (SwiftPM / CocoaPods):** surfaced updates, not applied. Commands the user should run to validate.

## Guard rails

- **Never bump past a known-incompatible major** (Kotlin 2.x, AGP 8.x → 9.x, Compose Multiplatform 1.7.x → 2.x, Koin 3.x → 4.x) without explicit `--group=` targeting. Major bumps usually involve coordinated changes across multiple refs.
- For `--group=compose-multiplatform`, remember the Compose Compiler embedded in Compose Multiplatform is **not** the same as AGP's Compose Compiler plugin — `:androidApp` may use either depending on the skeleton.
- For `--group=kotlin`, KSP **must** bump in lockstep (`<kotlinVersion>-<kspPatch>`). The command should not let them drift.
- For `--group=ktor`, remind the user to verify both engines (`OkHttp` on Android, `Darwin` on iOS) still resolve — Ktor occasionally renames artifacts.
- For `--group=sqldelight`, remind to re-run `./gradlew :shared:generateSqlDelightInterface` and re-test on iOS — code-gen breakage tends to surface there first.
- For `--group=koin`, remind to regenerate code via KSP after the bump (`./gradlew :shared:kspCommonMainKotlinMetadata`).

Delegate breakage triage to `kmm-build-expert` via the `Task` tool — that agent owns the Gradle / KMP / plugin-alignment side.
