---
description: Upgrade iOS dependencies (SwiftPM + optional CocoaPods) with a dry-run diff before applying. Self-sufficient — no extra plugins required.
argument-hint: "[--dry-run | --apply] [--group=<name>] [--package=<name>]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task, WebFetch
---

# /upgrade-deps

Refresh iOS dependencies. Source of truth depends on the package manager:

- **SwiftPM (preferred):** `Package.swift` declares versions; `Package.resolved` pins them. Most modern iOS projects are SwiftPM-first — including Firebase, Sentry, GRDB, Alamofire, Apollo, SnapKit, Lottie.
- **CocoaPods (legacy):** `Podfile` declares versions; `Podfile.lock` pins them. Skip this section entirely if `Podfile` is missing. Carthage is out of scope — hand off to `ios-build-expert`.

## Steps

1. Locate `Package.swift` (SwiftPM) and/or `Podfile` (CocoaPods) at the repo root. Bail with a clear message if neither exists.

2. **SwiftPM resolution.** Run `xcodebuild -resolvePackageDependencies` (or `swift package resolve` on a pure-SPM repo) to materialize the current `Package.resolved`. Then, for each remote package, **resolve the latest stable release by `WebFetch`-ing the GitHub releases API**:

   ```
   https://api.github.com/repos/<owner>/<repo>/releases/latest
   ```

   Fall back to `https://api.github.com/repos/<owner>/<repo>/tags` for repos that don't cut GitHub Releases (filter out `-alpha`, `-beta`, `-rc`, `-pre`, `-snapshot`, `-eap` suffixes; the latest stable is the highest semver tag that survives the filter).

   Per-requirement rules:
   - `.upToNextMajor(from: "x.y.z")` / `.upToNextMinor(from: "x.y.z")` — propose a bump to the latest stable **within the existing major**, unless `--group=<name>` or `--package=<name>` explicitly targets a major bump.
   - `.exact("x.y.z")` — only bump on explicit `--package=<name>` targeting; an `exact` pin is a deliberate choice.
   - `.branch(...)` / `.revision(...)` — surface to the user, do **not** auto-bump.

   **Optional speedup:** if the third-party [`swift-outdated`](https://github.com/kiliankoe/swift-outdated) CLI is installed (`which swift-outdated`), use its output as a hint. Treat it like Android's gradle-versions-plugin — still verify against the GitHub releases API because it can lag by a release.

3. **CocoaPods resolution** *(only if `Podfile` exists).* Run `pod outdated`. Parse its "newest version" column. For each pod, propose a bump to the new version, again capped to the current major unless `--group=` / `--package=` targets a major.

4. Build a proposed diff:
   - **`Package.swift`:** show the `.package(...)` line before / after.
   - **`Podfile`:** show the `pod '<Name>'` line before / after.
   - Group by area: networking (Alamofire, Apollo, Moya), persistence (GRDB, Realm), Firebase, observability (Sentry, Datadog), testing (Nimble, Quick, Cuckoo), UI (SnapKit, Lottie, Kingfisher), misc.
   - Skip any line tagged with a trailing `// pin: <reason>` comment.

5. **Sanity-check against the skeleton's toolchain floor** (`${CLAUDE_PLUGIN_ROOT}/skills/ios-app-skeleton/SKILL.md` → "Target floor", and `${CLAUDE_PLUGIN_ROOT}/skills/ios-app-skeleton/references/app-features.md` for the iOS 17 compatibility deltas). Surface any trap the proposed bump would hit — a Swift-tools bump that outruns the installed Xcode, a package whose new major raises its own minimum deployment target above the app's, or a Firebase bump that changes the `GoogleService-Info.plist` contract — and pick the next compatible version.

6. **Dry-run (default):** print the proposed diff. Stop. Ask: "Apply?"

7. **Apply** (`--apply`):
   - Write the new `Package.swift` (and `Podfile` if applicable).
   - **SwiftPM:** `swift package resolve` for project-wide; `swift package update <name>` for targeted upgrades. This refreshes `Package.resolved`.
   - **CocoaPods:** `pod update <Name>` for targeted; `pod update` for project-wide. This refreshes `Podfile.lock` and the `Pods/` checkout.
   - Validate: `xcodebuild test -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 15'` (or `swift test` on a pure-SPM library).
   - **If anything fails, revert** `Package.swift` + `Package.resolved` (and `Podfile` + `Podfile.lock` if touched) and surface the error. Do not leave the repo in a broken state.

8. Summarize:
   - Bumped versions (by group), each with old → new.
   - Skipped (pinned, pre-release, branch/revision, trap-blocked).
   - Post-bump checks: build result, test result.

## Guard rails

- **Never bump past a known-incompatible major** (Swift tools version, Firebase 11.x → 12.x, GRDB 6.x → 7.x) without explicit `--package=<name>` / `--group=<name>` targeting. Major bumps usually involve coordinated changes (API breaks, deployment target moves).
- **Firebase bumps:** remind the user to re-check `GoogleService-Info.plist` placement per scheme and that the dSYM upload script path may have moved.
- **Swift Concurrency-affecting bumps** (anything that toggles `Sendable` conformance on public types): mention that the project ships with Swift 6 concurrency on; a clean compile after the bump is the only proof.
- **CocoaPods + SwiftPM hybrid repos:** bump them in **separate runs**. Mixing both in one `--apply` pass makes the failure-revert path ambiguous.

Delegate breakage triage to `ios-build-expert` via the `Task` tool — that agent owns the xcodebuild / SPM / signing side.
