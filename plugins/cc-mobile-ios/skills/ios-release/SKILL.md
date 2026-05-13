---
name: ios-release
description: Release-time conventions for this iOS project — `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` bumps in `.xcconfig`, signing via `fastlane match`, App Store metadata + `release_notes.txt` layout, dSYM upload to Crashlytics / Sentry, and the pre-release `xcodebuild` command sequence. Load whenever cutting a build, bumping marketing or build version, regenerating signing assets, or shipping to TestFlight / App Store Connect. Intentionally small — does not duplicate the full app scaffolding (see `ios-app-skeleton` for that).
---

# iOS release

Everything a release pass touches, and nothing it doesn't. This skill is intentionally small (one page) so it's cheap for `ios-release-engineer` to preload — the bigger `ios-app-skeleton` skill is overkill for shipping work.

## Version-bump shape

Two fields move per release:

- **`CFBundleShortVersionString`** — the user-visible marketing version (`1.4.0`). Backed by `MARKETING_VERSION` in modern Xcode projects.
- **`CFBundleVersion`** — the build number (`117`). Backed by `CURRENT_PROJECT_VERSION`. Must be **strictly monotonic for a given marketing version** — App Store Connect / TestFlight rejects an upload whose build number is `≤` any already-uploaded build under the same `CFBundleShortVersionString`. Resetting the build number when bumping marketing version is allowed but optional; treating it as globally monotonic is simpler and avoids accidental clashes.

Where they live:

- **xcconfig (preferred):** `Config/App.xcconfig` (or per-scheme `App-Debug.xcconfig` / `App-Release.xcconfig`) carries `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`. Edit the xcconfig, not the `.pbxproj`.
- **Info.plist:** for projects that haven't migrated, the values are inline as `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` referencing build settings, or hard-coded. Hard-coded is a smell — flag it during release and migrate.
- **project.pbxproj:** never hand-edit the signing or version blocks. xcconfig overrides, or `agvtool`, are the supported paths.

CLI levers:

```bash
# Marketing version (CFBundleShortVersionString)
agvtool new-marketing-version 1.4.0

# Build number (CFBundleVersion)
agvtool new-version -all 117

# Confirm what the next archive will use
xcodebuild -showBuildSettings -scheme AppProd -configuration Release \
  | grep -E 'MARKETING_VERSION|CURRENT_PROJECT_VERSION'
```

Rules:
- Read the xcconfig (or the `agvtool what-version` / `agvtool what-marketing-version` output) before bumping. Concurrent PRs that both bump are the most common merge conflict — land a bump that's strictly higher than what's on the release branch *right now*.
- Build number is monotonic across **every** build flavor uploaded for a given marketing version, not per scheme. If `AppDev` ships `(1.4.0, 117)` to internal TestFlight, the next `AppProd` upload for `1.4.0` must be `≥ 118`.

## Signing & code signing

Two supported paths. Pick one per project and stick with it.

- **Apple automatic signing.** Xcode manages certificates + provisioning profiles tied to your Team ID. Fine for single-developer projects. Falls apart on CI because the headless runner can't trigger Xcode's UI flow.
- **`fastlane match` (preferred for teams + CI).** Git-based shared signing assets, encrypted at rest. `match appstore`, `match development`, `match adhoc` regenerate / fetch the right profile + cert for the right type. CI authenticates to the repo via SSH key or PAT; certificates are decrypted with the `MATCH_PASSWORD` secret.

Profile types: **App Store** (TestFlight + production), **Ad Hoc** (UDID-restricted distribution), **Development** (Xcode debug runs), **Enterprise** (in-house distribution, never via App Store Connect).

Keep code-signing material out of the repo:

```
# .gitignore
*.p12
*.mobileprovision
*.cer
fastlane/report.xml
fastlane/Preview.html
fastlane/test_output
fastlane/screenshots
```

On CI, fetch credentials via:
- **`fastlane match`** — pulls from the match repo using `MATCH_PASSWORD`.
- **App Store Connect API key** (`.p8` file) — preferred over Apple ID for `fastlane pilot upload` / `fastlane deliver`. Base64-encode the `.p8` into a CI secret; decode at runtime; pass `--api-key-path`.

## fastlane release notes layout

App Store metadata is one file per locale, **overwritten each release** (App Store Connect only displays the latest version's notes — this differs from Android's per-`versionCode` history under `changelogs/`):

```
fastlane/
└── metadata/
    ├── en-US/
    │   ├── release_notes.txt   # ≤ 4000 chars, plain text
    │   ├── description.txt
    │   └── keywords.txt
    └── fr-FR/
        └── release_notes.txt
```

`fastlane deliver` reads the whole `metadata/` tree on upload. Missing `release_notes.txt` for a locale that's already published in App Store Connect is a release blocker — `deliver` will fail, and even if forced through it ships a blank "What's New" to that locale.

## dSYM upload (Crashlytics / Sentry)

Without dSYMs, crash reports are unsymbolicated. `xcodebuild -exportArchive` writes dSYMs to the `.xcarchive` bundle under `dSYMs/`.

- **Firebase Crashlytics:** the `Firebase` SPM package ships an `upload-symbols` script. Wire it as a Run Script build phase **after** the "Embed Frameworks" phase:

  ```bash
  "${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols" \
    -gsp "${PROJECT_DIR}/GoogleService-Info.plist" -p ios "${DWARF_DSYM_FOLDER_PATH}"
  ```

  For CI archives, run it once against the archive's `dSYMs/`:

  ```bash
  ./Crashlytics/upload-symbols -gsp GoogleService-Info.plist -p ios build/App.xcarchive/dSYMs
  ```

- **Sentry:** `sentry-cli upload-dif --org $ORG --project $PROJECT build/App.xcarchive/dSYMs`. Same pattern — point it at the archive.

Bitcode is dead (Xcode 14+ drops it), so App Store Connect no longer regenerates dSYMs on its side. If you skip the upload, the symbols are gone.

## Pre-release command sequence

Run sequentially; bail on the first failure:

```bash
# 1. Tests
xcodebuild test \
  -scheme AppProd \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# 2. Archive
xcodebuild archive \
  -scheme AppProd \
  -configuration Release \
  -archivePath build/AppProd.xcarchive

# 3. Export .ipa
xcodebuild -exportArchive \
  -archivePath build/AppProd.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist Config/ExportOptions.plist

# 4. dSYM upload (Crashlytics or Sentry — pick one)
./Pods/FirebaseCrashlytics/upload-symbols \
  -gsp GoogleService-Info.plist -p ios build/AppProd.xcarchive/dSYMs

# 5. TestFlight (or App Store)
fastlane pilot upload --ipa build/ipa/AppProd.ipa     # TestFlight
# fastlane deliver --ipa build/ipa/AppProd.ipa        # App Store submission
```

`ExportOptions.plist` lives in `Config/` and pins `method` (`app-store` / `ad-hoc` / `development`), `teamID`, and `signingStyle` (`manual` if using `match`).

## Pre-release checklist

Verify, in this order:

1. **Build number is strictly greater** than the highest already-uploaded build for the same `CFBundleShortVersionString` across **every** internal / external TestFlight group and App Store production.
2. **`xcodebuild -showBuildSettings -scheme AppProd -configuration Release | grep -E 'MARKETING_VERSION|CURRENT_PROJECT_VERSION'`** confirms what the archive will actually use — not just what the xcconfig says.
3. **dSYMs uploaded** to Crashlytics / Sentry for the archive you're about to ship.
4. **`release_notes.txt` exists** under `fastlane/metadata/<locale>/` for every locale already published in App Store Connect.
5. **Signing identity present** — `fastlane match appstore --readonly` (or Xcode "Signing & Capabilities" if on automatic signing) resolves a non-expired distribution cert + matching App Store provisioning profile.
6. **Encryption export compliance** declared in `Info.plist` via `ITSAppUsesNonExemptEncryption`, or attested in App Store Connect per upload.
7. **Privacy nutrition labels** + **App Privacy Report** entries up-to-date in App Store Connect (these are answered in the web console, not the repo — but a release pass confirms nothing material has changed).

## What the release engineer doesn't do

- **No feature changes.** If a release is blocked by a bug, file it and hand off — `ios-architect` or `ios-build-expert` fixes.
- **No `CODE_SIGN_STYLE` swap** (automatic ↔ manual) without explicit ask. It quietly changes how every dev's local build resolves signing.
- **No manual edits to `project.pbxproj`'s signing or version blocks.** Use xcconfig overrides or `agvtool`.
- **No commits of signing material.** `.p12`, `.mobileprovision`, `.cer`, the unencrypted `fastlane match` repo — none of these touch your repo.

## Hard nos

- No reusing a build number across TestFlight uploads for the same marketing version. App Store Connect doesn't allow it; nor does this skill.
- No archiving from a dirty working tree. The git SHA embedded in build metadata becomes a lie.
- No `fastlane deliver --skip-metadata` to "ship faster" — the metadata is part of the release record.
- No bumping the marketing version without a corresponding `release_notes.txt` refresh per locale.
- No shipping a `Release` build with `DEBUG` Swift compilation flags set, or with `ENABLE_TESTABILITY=YES` left over from a profiling session.
