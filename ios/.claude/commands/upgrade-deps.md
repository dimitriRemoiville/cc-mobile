---
description: Upgrade Swift Package Manager dependencies with a dry-run diff before applying.
argument-hint: [--dry-run | --apply] [--package=<name>]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /upgrade-deps

1. Locate `Package.swift` (and/or the Xcode project's `Package.resolved`). Bail if the project uses CocoaPods or Carthage — hand off to `ios-build-expert`.
2. Run `xcodebuild -resolvePackageDependencies` to materialize current resolved versions.
3. For each dependency, inspect the declared requirement:
   - `.upToNextMajor(from:)` / `.upToNextMinor(from:)` / `.exact` / branch pins.
   - Flag any branch or commit-hash pin: surface to user but do not auto-bump.
4. Query upstream tags via git ls-remote for each dependency to identify the latest release.
5. Build a proposed diff for `Package.swift`:
   - Only bump within the existing requirement's major unless `--package=<name>` explicitly requests major bump.
   - Group by area: networking (Alamofire, Apollo), persistence (GRDB, Realm), Firebase, testing, UI (SnapKit, Lottie), misc.
6. **Dry-run (default)**: print the proposed diff. Stop. Ask: "Apply?"
7. **Apply**:
   - Edit `Package.swift`.
   - Run `xcodebuild -resolvePackageDependencies` to refresh `Package.resolved`.
   - Run `xcodebuild build -scheme App -destination 'generic/platform=iOS'` to catch breakage.
   - Run the test scheme.
   - If any step fails, revert `Package.swift` and `Package.resolved`, surface the error.
8. Summarize: bumped, skipped (pinned / branch), build result, test result.

## Guard rails

- Never bump past a major without `--package=<name>`.
- If the bump touches Firebase, check that `GoogleService-Info.plist` is still in the target.
- If the bump touches a package that exposes public types in your app API, run `swift build --target App --show-bin-path` + grep for API changes and surface them.

Delegate breakage triage to `ios-build-expert`.
