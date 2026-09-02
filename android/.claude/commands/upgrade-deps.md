---
description: Upgrade Android dependencies from the version catalog with a dry-run diff before applying. Self-sufficient — no Gradle plugin dependency.
argument-hint: "[--dry-run | --apply] [--group=androidx|kotlin|compose|hilt|firebase]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task, WebFetch
---

# /upgrade-deps

Upgrade dependencies declared in `gradle/libs.versions.toml`. Resolution is done by walking each ref's `maven-metadata.xml` directly — the same mechanism `/init-android-app` Phase 1.5 uses — so this command works on a freshly-scaffolded project with no extra Gradle plugins.

## Steps

1. Locate `gradle/libs.versions.toml`. Bail if it doesn't exist (this command requires a version catalog; hand off to `android-build-expert` if the project predates one).

2. **Resolve the latest stable for each `[versions]` ref by `WebFetch`-ing its `maven-metadata.xml`** (reuse the URL table from `.claude/commands/init-android-app.md` → "Phase 1.5"). Filter out any `-alpha`, `-beta`, `-RC`, `-rc`, `-dev`, `-SNAPSHOT`, `-eap` suffixes. For `ksp`, filter to versions starting with the resolved Kotlin version (KSP is `<kotlinVersion>-<kspPatch>`). The `kotlin-compose` plugin rides the `kotlin` ref — no separate fetch.
   - **Optional speedup:** if the project ships `com.github.ben-manes.versions` (the Ben-Manes "gradle-versions-plugin"), you can run `./gradlew dependencyUpdates -DoutputFormatter=plain -Drevision=release` instead. Treat its output as a hint, not a substitute — still verify with `maven-metadata.xml` because the plugin is sometimes a release behind.

3. Build a proposed diff for `libs.versions.toml`:
   - Only bump within the major currently in use **unless** `--group=...` explicitly targets a major bump.
   - Skip any version line that has a trailing `# pin: <reason>` comment.
   - Group by area in the output: AndroidX, Kotlin / KSP / Compose compiler, Compose BOM, Hilt, Firebase, testing, other.

4. **Sanity-check against the skeleton's "Compatibility traps" table** (`.claude/skills/android-app-skeleton/references/root-files.md` → "Compatibility traps"). If a proposed bump would land in a known trap (e.g. AGP 9 + Hilt < 2.59 / Compose Compiler plugin missing on a Compose module), surface the trap in the diff and pick the next compatible version.

5. **Dry-run (default)**: print the proposed `toml` diff to the user. Stop. Ask: "Apply?"

6. **Apply** (`--apply`):
   - Write the new `toml`.
   - Run `./gradlew :app:dependencies --configuration releaseRuntimeClasspath` to validate resolution.
   - Run `./gradlew :app:lintDebug :app:testDebugUnitTest :app:assembleDevDebug` (the assemble catches plugin-shape regressions like a missing Compose Compiler plugin alias).
   - If anything fails, **revert the `toml`** and surface the error. Do not leave the repo in a broken state.

7. Summarize:
   - Bumped versions (by group), each with old → new.
   - Skipped (pinned, pre-release, trap-blocked).
   - Post-bump checks: lint result, unit test result, assemble result.

## Guard rails

- **Never bump past a known-incompatible major** (Kotlin 2.x, AGP 8.x → 9.x, Compose compiler) without explicit `--group=` targeting. Major bumps usually involve coordinated changes across multiple refs (e.g. Kotlin → KSP → Compose Compiler → coroutines).
- For `--group=compose`, also remind the user that the Compose Compiler plugin alias rides the `kotlin` ref; if Kotlin needs a bump the alias follows automatically.
- For `--group=hilt`, remind to regenerate code via KSP after the bump (`./gradlew :app:kspDebugKotlin`).
- If the diff touches Firebase, remind to re-run `google-services.json` sync check on each flavor.

Delegate breakage triage to `android-build-expert` via the `Task` tool — that agent owns the Gradle / KSP / plugin-alignment side.
