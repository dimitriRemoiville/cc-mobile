---
description: Upgrade Android dependencies from the version catalog with a dry-run diff before applying.
argument-hint: [--dry-run | --apply] [--group=androidx|kotlin|compose|hilt|firebase]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /upgrade-deps

1. Locate `gradle/libs.versions.toml`. Bail if it doesn't exist (this command requires a version catalog; hand off to the `android-build-expert` if the project predates one).
2. Run `./gradlew dependencyUpdates -DoutputFormatter=plain -Drevision=release` (via the gradle-versions-plugin if present; otherwise skip and note the limitation).
3. Build a proposed diff for `libs.versions.toml`:
   - Only bump within the major currently in use unless `--group=...` explicitly targets a major bump.
   - Skip any version marked `// pin:` with a trailing comment.
   - Group by area in the output: AndroidX, Kotlin / KSP / Compose compiler, Compose BOM, Hilt, Firebase, testing, other.
4. **Dry-run (default)**: print the proposed `toml` diff to the user. Stop. Ask: "Apply?"
5. **Apply**:
   - Write the new `toml`.
   - Run `./gradlew :app:dependencies --configuration releaseRuntimeClasspath` to validate resolution.
   - Run `./gradlew :app:lintDebug :app:testDebugUnitTest` to catch obvious breakage.
   - If anything fails, revert the `toml` and surface the error. Do not leave the repo in a broken state.
6. Summarize:
   - Bumped versions (by group).
   - Skipped (pinned or pre-release).
   - Post-bump checks: lint result, unit test result.

## Guard rails

- Never bump past a known-incompatible major (Kotlin 2.x, AGP 8.x, Compose compiler BOM) without explicit `--group=` targeting.
- For `--group=compose`, also remind the user to bump Kotlin if the compiler version requires it.
- For `--group=hilt`, remind to regenerate code via KSP after the bump.
- If the diff touches Firebase, remind to re-run `google-services.json` sync check.

Delegate breakage triage to `android-build-expert` via the Task tool.
