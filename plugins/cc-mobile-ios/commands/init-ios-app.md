---
description: Scaffold a fresh iOS app with this project's conventions — Swift 6, SwiftUI, Clean Architecture, Swift Concurrency, SPM-based modules, composition-root DI, URLSession, Keychain, NavigationStack with typed destinations, Swift Testing.
argument-hint: "[bundle_id]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task, AskUserQuestion
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

Read `.claude/skills/ios-app-skeleton/SKILL.md` in full. Source of truth for every file, every placeholder, every flag.

Placeholders used: `{{APP_NAME}}`, `{{BUNDLE_ID}}`, `{{APP_DISPLAY_NAME}}`, `{{ORG_NAME}}`.

Flags: `INCLUDE_SWIFTDATA`, `INCLUDE_FIREBASE`.

Do not improvise file contents. Substitute placeholders.

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
- User picks Firebase without project set up → proceed but flag manual plist drop.
