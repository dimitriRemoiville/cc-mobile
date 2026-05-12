---
name: android-release
description: Release-time conventions for this Android project — version bumps in `app/build.gradle.kts`, the `keystore.properties`-driven signing config, fastlane changelog file layout, Baseline Profile regeneration, Crashlytics mapping upload, and the pre-release Gradle command sequence. Load whenever cutting a build, bumping versionCode / versionName, regenerating signing config, or shipping to Play Console. Intentionally small — does not duplicate the full app scaffolding (see `android-app-skeleton` for that).
---

# Android release

Everything a release pass touches, and nothing it doesn't. This skill is intentionally small (one page) so it's cheap for `android-release-engineer` to preload — the bigger `android-app-skeleton` skill is overkill for shipping work.

## Version-bump shape

`app/build.gradle.kts` is the source of truth. Two fields move per release:

```kts
android {
    defaultConfig {
        versionCode = 17        // strictly increasing across all shipped builds, every flavor
        versionName = "1.4.0"   // semver-ish, user-visible
    }
}
```

Rules:
- `versionCode` is **monotonic across the whole app**, not per flavor. Play Console rejects a track with a code ≤ the highest already-shipped code on **any** track. If you have `dev` + `prod` flavors and ship `prod` with `versionCode = 17`, the next `dev` build must be `≥ 18`, not `17`.
- `versionName` is whatever marketing wants. Don't gate the build on it.
- Read the file before bumping. Concurrent PRs that both bump are the most common merge conflict — your job is to land the bump that's strictly higher than what's on the release branch *right now*.

## Signing config (`keystore.properties`-driven)

The signing block reads from a root-level `keystore.properties` file. The example template that ships in the scaffold:

```properties
# keystore.properties.example  (committed; the real file is gitignored)
# Path is resolved relative to the repository root.
storeFile=release.keystore
storePassword=changeme
keyAlias=release
keyPassword=changeme
```

Wire-up in `app/build.gradle.kts`:

```kts
val keystoreProps = Properties().apply {
    val f = rootProject.file("keystore.properties")
    if (f.exists()) f.inputStream().use(::load)
}

android {
    signingConfigs {
        if (keystoreProps.isNotEmpty()) {
            create("release") {
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            if (keystoreProps.isNotEmpty()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}
```

Rules:
- The block is **silent** until `keystore.properties` exists — that's why local debug builds work for contributors who don't have the keystore.
- On CI: write `keystore.properties` from a CI secret before `./gradlew`, never check it in. Decode the keystore from a base64 secret too.
- `.gitignore` must include `keystore.properties` and `*.keystore` (and, if Firebase, `/app/src/*/google-services.json`).

For first-time keystore generation:

```bash
keytool -genkey -v \
  -keystore release.keystore \
  -alias release \
  -keyalg RSA -keysize 2048 -validity 10000
```

## fastlane changelog layout

Release notes live under fastlane's expected layout — `supply` reads them automatically when uploading to Play Console:

```
fastlane/
└── metadata/
    └── android/
        ├── en-US/
        │   └── changelogs/
        │       ├── 16.txt   # versionCode → release notes (≤ 500 chars)
        │       └── 17.txt
        └── fr-FR/
            └── changelogs/
                └── 17.txt
```

One `<versionCode>.txt` per locale. Missing locales fall back to `en-US`. Don't commit a changelog for a `versionCode` that doesn't exist yet — `supply` errors on dangling files.

## Baseline Profile regeneration

Re-record whenever you've touched a hot path the profile already covers (startup, first screen, top navigation flow):

```bash
./gradlew :app:generateReleaseBaselineProfile
```

The generated `baseline-prof.txt` lands under `app/src/release/generated/baselineProfiles/`. Commit it. **Don't hand-edit.** If the diff looks weird (huge churn for a small change), re-run on a clean device — the recording is environment-sensitive.

CI policy: regenerate manually with code review, **not** every PR. Continuous regeneration drowns the diff in noise and defeats the point of pinning.

## Crashlytics mapping

`./gradlew :app:assembleRelease` (or `bundleRelease`) generates the R8 mapping. Upload it for symbolicated stack traces:

```bash
./gradlew :app:uploadCrashlyticsMappingFileRelease
```

This task only exists when the Crashlytics Gradle plugin is applied (`INCLUDE_FIREBASE`). On Firebase-less projects skip it; on Firebase projects, automate it in CI right after the release build.

## Bundle vs APK

- **`./gradlew :app:bundleRelease`** → `.aab` for Play Store uploads. This is the default for shipping.
- **`./gradlew :app:assembleRelease`** → `.apk` for sideload, internal distribution, smoke testing. Don't upload an `.apk` to Play Console — the dynamic delivery features (per-device APK split) only work from a bundle.

## Pre-release checklist

Run sequentially; bail on the first failure:

```bash
./gradlew :app:lintRelease :app:testReleaseUnitTest :app:bundleRelease
```

`bundleRelease` already runs the per-variant R8 + signing pipeline, so adding `:app:assembleRelease` to the same command roughly doubles the time for no extra coverage. Run `assembleRelease` separately only when you need an `.apk` for sideload / internal QA distribution.

Then verify, in this order:

1. **`versionCode` is strictly greater than the last shipped code on every track** (`internal`, `closed`, `production`).
2. **Baseline Profile is up to date** for any hot-path changes since last release (re-record if unsure).
3. **Changelog file exists** under `fastlane/metadata/android/<locale>/changelogs/<versionCode>.txt` for every locale you ship to.
4. **Crashlytics mapping uploaded** (Firebase projects only).
5. **`google-services.json`** is in place per flavor (Firebase projects only). The skeleton's `tasks.matching { processGoogleServices }.onlyIf { ... }` guard skips per-variant when missing — at release time the JSON must actually be present, not skipped.
6. **Signing config wired** — confirm `app/build/outputs/bundle/<flavor>Release/` has a signed `.aab`, not an unsigned one.

## What the release engineer doesn't do

- **No feature changes.** If a release is blocked by a bug, file it and hand off — `android-architect` or `android-build-expert` fixes.
- **No ProGuard / R8 rule edits** that weren't requested by a crash or build failure. New rules go through `android-build-expert`.
- **No commits of signing material.** Keystores, `keystore.properties`, decoded base64 secrets — none of these touch the repo.

## Hard nos

- No `versionCode` reuse across tracks. Play Console doesn't allow it; nor does this skill.
- No bundling debug symbols into the release `.aab` — they bloat the download. The Crashlytics upload + the mapping file is how you get symbolication without shipping symbols.
- No `fastlane supply --skip-upload-changelogs` to "ship faster" — the changelog is part of the release record.
- No `applicationIdSuffix` change between releases of the same shipped flavor — it's a different app from Play Console's perspective and resets ratings/reviews.
