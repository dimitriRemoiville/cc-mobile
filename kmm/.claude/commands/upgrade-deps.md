---
description: Upgrade KMP dependencies via the Gradle version catalog with a dry-run diff.
argument-hint: [--dry-run | --apply] [--group=kotlin|ktor|coroutines|serialization|sqldelight|koin]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /upgrade-deps

1. Locate `gradle/libs.versions.toml`. Bail if missing.
2. Run the gradle-versions-plugin if present: `./gradlew dependencyUpdates -DoutputFormatter=plain -Drevision=release`.
3. For each dependency, propose a bump within the current major unless `--group=...` targets a major bump.
4. Extra care:
   - **Kotlin** + **KSP** + **Compose compiler** versions are tightly coupled. Bumping Kotlin requires bumping KSP (`<kotlin>-1.0.<n>`) and potentially Compose BOM. Bundle these in one change or refuse.
   - **Ktor** ties to **kotlinx-coroutines** and **kotlinx-serialization** — bump together.
   - **SQLDelight** bumps sometimes require code-gen changes; warn the user.
   - **Koin** 3.x -> 4.x is a breaking bump for `startKoin`; flag and require `--group=koin` explicit.
5. **Dry-run (default)**: print the proposed `toml` diff, grouped. Stop. Ask: "Apply?"
6. **Apply**:
   - Write the new `toml`.
   - Run `./gradlew :shared:allTests` (includes commonTest + JVM).
   - If iOS simulator is available, run `./gradlew :shared:iosSimulatorArm64Test`.
   - Build both apps: `./gradlew :androidApp:assembleDebug` and `./gradlew :shared:podspec` (if using CocoaPods) or `./gradlew :shared:linkPodDebugFrameworkIosSimulatorArm64`.
   - Revert on failure; surface the error.
7. Summarize: bumped (by group), skipped (pinned / prerelease), build + test results across targets.

Delegate breakage triage to `kmm-build-expert`.
