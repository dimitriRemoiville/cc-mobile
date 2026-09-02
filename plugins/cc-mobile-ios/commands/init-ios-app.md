---
description: Scaffold a fresh iOS app with this project's conventions — Swift 6, SwiftUI, Clean Architecture, Swift Concurrency, SPM-based modules, composition-root DI, URLSession, Keychain, NavigationStack with typed destinations, Swift Testing.
argument-hint: "[bundle_id]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task, AskUserQuestion, WebFetch
---

# /init-ios-app

You are scaffolding a brand-new iOS application from scratch. **Nothing is generated until Phase 0 is answered** — flags materially change the generated files.

## Phase 0 — Gather inputs

Use `AskUserQuestion` (propose defaults, one round-trip):

1. **App display name** (free-text, e.g. "My App").
2. **Bundle identifier** (reverse-DNS, e.g. `com.example.myapp`). If `$ARGUMENTS` is provided, use as default.
3. **Deployment target** (default iOS 18).
4. **Include SwiftData persistence?** (yes/no) — drives `INCLUDE_SWIFTDATA`.
5. **Include Firebase (Crashlytics + Analytics)?** (yes/no) — drives `INCLUDE_FIREBASE`. Warn: requires manual `GoogleService-Info.plist` drop per-scheme.
6. **Flavors/schemes**: `dev` + `prod` (default yes).

Confirm the plan in one short paragraph. Proceed only after confirmation.

## Phase 1 — Load the blueprint

Read `${CLAUDE_PLUGIN_ROOT}/skills/ios-app-skeleton/SKILL.md` in full. It is the procedure spine — placeholders, feature flags, target layout, execution order, hard rules, and post-scaffold checklist. The file templates live in sibling files under `references/` (e.g. `references/root-files.md`, `references/app-core.md`, `references/app-target.md`); each execution-order step in the spine names the reference it needs. Load each reference at its step rather than reading them all up front.

Placeholders used: `{{APP_NAME}}`, `{{BUNDLE_ID}}`, `{{APP_DISPLAY_NAME}}`, `{{ORG_NAME}}`.

Flags: `INCLUDE_SWIFTDATA`, `INCLUDE_FIREBASE`.

Do not improvise file contents. Substitute placeholders.

## Phase 1.5 — Resolve toolchain + SPM versions online

iOS scaffolding's "version surface" splits in three: (a) the Swift/Xcode toolchain on the user's machine, (b) Apple frameworks (no external version — they're a function of the deployment target), and (c) any third-party SPM packages we add. The Apple side is verified by command, not by URL fetch; the third-party side resolves through the GitHub Releases API because SPM doesn't have a Maven-style metadata XML.

**1. Toolchain floor (mandatory).** Run these locally and stop on a mismatch:

| Check | Command | Floor |
|---|---|---|
| Swift compiler | `swift --version` (parse `Apple Swift version <X.Y>`) | `>= 6.0` (the skeleton uses Swift 6 strict concurrency) |
| Xcode | `xcodebuild -version` (parse `Xcode <X.Y>`) | `>= 16.0` (Xcode 16 ships Swift 6) |
| `xcrun --show-sdk-version --sdk iphoneos` | `>= <user-picked deployment target>` | matches Phase 0 Q3 |

If Swift < 6 or Xcode < 16, stop and ask the user to upgrade — do not lower the floor or change the skeleton's idioms. Do not auto-suggest `xcode-select` switches — the user might have a beta intentionally selected.

**2. Deployment-target sanity.** If Phase 0 Q3 picked iOS < 18, surface that the skeleton uses iOS 18 features (`@Observable`, NavigationStack typed destinations, NavigationPath value-type push) and either (a) stop and ask the user to confirm a downgrade with eyes open, or (b) proceed and substitute the iOS 17-compatible variants documented in `${CLAUDE_PLUGIN_ROOT}/skills/ios-app-skeleton/references/app-features.md`. Anything below iOS 17 is a different skeleton — stop rather than improvise. Default behaviour: stop.

**3. Third-party SPM packages (only when flags require them).** SPM's manifest cares about real released tags. For each package the scaffold adds, resolve the latest stable tag via GitHub's Releases API and pin it with the `from:` form (`.package(url: "...", from: "<tag>")`).

| Flag | Package | URL | API to fetch |
|---|---|---|---|
| `INCLUDE_FIREBASE` | firebase-ios-sdk | `https://github.com/firebase/firebase-ios-sdk` | `https://api.github.com/repos/firebase/firebase-ios-sdk/releases/latest` (read `tag_name`) |
| (always) | swift-collections | `https://github.com/apple/swift-collections` | `https://api.github.com/repos/apple/swift-collections/releases/latest` — only if the skeleton currently depends on it; skip otherwise |

For each fetch: filter out tags suffixed `-alpha`, `-beta`, `-rc`, `-pre`. Use the highest remaining semver. If the GitHub API rate-limits (HTTP 403 with `X-RateLimit-Remaining: 0`), fall back to `git ls-remote --tags <url>` (run via Bash) and pick the highest semver tag manually. Stop and surface the failure if both routes fail — do not invent a tag.

**4. Optional tooling.** If `xcodegen` is missing, stop and ask the user to either install it (`brew install xcodegen`) or accept the manual-Xcode-project path emitted in Phase 2 step 5. Do not silently degrade to manual without asking.

**Resolution output.** Before Phase 2, print the resolved toolchain row and the resolved SPM tag(s) so the user can sanity-check them. Example:

```
Resolved versions:
  swift          = 6.0.2     (local)
  xcode          = 16.2      (local)
  ios deployment = 18.0      (user)
  firebase-ios   = 11.6.0    (github releases, INCLUDE_FIREBASE=on)
```

## Phase 2 — Execute the scaffold

Follow the skill's procedure:

1. Create `{{APP_NAME}}/` directory. The skeleton is **SPM-first**: `Package.swift` at the root of a Swift package + a thin Xcode project that embeds it.
2. Generate `Package.swift` with three products:
   - `AppCore` (internal lib) — DomainError, Outcome, protocols.
   - `AppFeatures` (internal lib) — SwiftUI views + view models.
   - `App` (app target) — wires everything.
3. Generate the SPM source tree under `Sources/`:
   - `Sources/AppCore/` — `Outcome.swift`, `DomainError.swift`, `APIClient.swift` protocol, `KeychainStore.swift` protocol.
   - `Sources/AppFeatures/Splash/` — `SplashView.swift`, `SplashViewModel.swift`, typed destinations, `#Preview`.
   - `Sources/App/` — `{{APP_NAME}}App.swift`, `CompositionRoot.swift`, `URLSessionAPIClient.swift`, `KeychainStore+Keychain.swift`.
4. Generate tests under `Tests/`:
   - `Tests/AppCoreTests/` — one test for `Outcome`.
   - `Tests/AppFeaturesTests/` — one Swift Testing test for `SplashViewModel`.
5. Generate an Xcode project shim via `xcodegen` if installed, else print the manual steps and stop with a prompt.
6. (Optional, if `xcodegen` present) Emit `project.yml` from the skeleton and run `xcodegen generate`.
7. Run `swift build` at the SPM package level to verify the package compiles.
8. Run `swift test` to verify the tests run.
9. If an Xcode project was generated, run `xcodebuild -scheme App -destination 'generic/platform=iOS' build` (may need simulator).
10. Emit the manual setup note — signing, App Groups (if any), push entitlements, Firebase plist drop.

## Phase 3 — Post-init checklist

Print a concise checklist:

```
Scaffold complete. Next steps:

☐ Open the Xcode project, configure signing (Signing & Capabilities → Team).
☐ Create dev + prod schemes in Xcode if you haven't (duplicate the default, set Info.plist values per scheme, pass -Darg to the build).
☐ [if Firebase] drop GoogleService-Info.plist for dev + prod, assign per scheme.
☐ [if SwiftData] verify the ModelContainer boots in a UI test.
☐ Replace the splash view placeholder with your first real feature.

Build it:
  swift build
  swift test
  (Xcode) ⌘R on the App scheme
```

## Ground rules

- Stay inside the `ClaudeCodeMobile` workspace unless the user points to a different parent directory.
- One command per Bash call where it matters.
- Never commit.
- Do not scaffold features — stop at a runnable splash.
- Do not create unsolicited docs.

## When to say no

- Target dir already contains `Package.swift` or `*.xcodeproj` → ask whether to abort or scaffold into a subdirectory.
- `swift` / `xcodebuild` not on PATH → stop.
- Local Swift < 6.0 or Xcode < 16 → stop (Phase 1.5). Don't lower the skeleton's floor.
- Phase 1.5 GitHub release fetch fails AND `git ls-remote` fallback fails → stop. Don't invent SPM tags from training data.
- User picks Firebase without project set up → proceed but flag manual plist drop. The defensive `FirebaseAnalyticsTracker` no-ops at runtime until `FirebaseApp` is configured, so the scaffold still launches.
