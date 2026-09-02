# cc-mobile-ios

Opinionated Claude Code setup for iOS apps — Swift + SwiftUI, MVVM + Clean Architecture, `@Observable` state holders on `@MainActor`, URLSession + Codable, SwiftData + Keychain, `NavigationStack` typed routes.

## What you get when you install

**Slash commands**

- `/init-ios-app` — scaffold a brand-new iOS app end-to-end (Xcode project structure, Swift Package dependencies, core/ base classes, `NavigationStack`, composition root, tests).
- `/new-feature <name>` — scaffold a full feature (data + domain + presentation + composition + nav destination).
- `/add-view <feature>/<Name>` — add a SwiftUI view + ViewModel + nav route.
- `/add-usecase <feature>/<Name>` — add a domain use case.
- `/add-migration` — add a SwiftData migration plan.
- `/fix-tests` — triage and repair broken tests.
- `/upgrade-deps` — walk through Swift Package upgrades safely.
- `/review-ios` — delegate a review to the `ios-reviewer` agent.

**Specialist agents**

- `ios-architect` — architectural decisions, layer boundaries, `@Observable` + state flow.
- `ios-ui-engineer` — SwiftUI views, `NavigationStack` typed routes, environment wiring.
- `ios-reviewer` — idiom + layer + state + concurrency review (primary reviewer).
- `ios-tester` — Swift Testing + hand-rolled fakes + snapshot tests.
- `ios-build-expert` — Xcode project layout, SPM packages, build configurations, CI.
- `ios-performance-analyst` — Instruments, hitch rate, memory, launch time.
- `ios-security-reviewer` — Keychain, CryptoKit, App Transport Security, secrets.
- `ios-a11y-reviewer` — VoiceOver, Dynamic Type, focus, contrast.
- `ios-release-engineer` — versioning, signing, App Store Connect uploads, phased rollouts.

**Skills** (auto-loaded by domain)

- `ios-architecture` — layer rules per feature, composition root patterns.
- `swift-style` — the project delta only: `Outcome<Success>` / `DomainError` contract, typed IDs, use-case naming, target boundaries, logging privacy.
- `swift-concurrency` — the isolation map (`@MainActor` view models, `actor` repositories), the cancellation contract, `@concurrent` offloading, the hard nos.
- `swiftui-views` — the RootView/View split, `ViewState` shape, the `@Observable @MainActor` contract, Figma-to-asset-catalog token translation.
- `navigation-stack` — typed routes, value-driven navigation, deep links.
- `ios-di` — composition root + initializer injection (no magic container).
- `urlsession-networking` — the `APIClient` protocol boundary, DTO/domain separation, where `APIError` stops and `DomainError` starts, the `URLProtocol` test seam.
- `swiftdata-persistence` — model schema, migrations, queries, testing.
- `keychain-secure-storage` — the single `KeychainStore` seam, `ThisDeviceOnly` accessibility policy, `.biometryCurrentSet` gating, access-group sharing.
- `ios-testing` — Swift Testing for units, XCTest for UI, `@MainActor` view-model suites, stubs vs fakes, the `MockURLProtocol` seam.
- `ios-accessibility` — semantics, traits, Dynamic Type, rotor navigation.
- `ios-security` — ATS, SPKI cert pinning with rotation, App Attest, file protection, WebKit and URL-scheme rules.
- `ios-performance` — Instruments, hitch rate, `LazyVStack`, image decoding.
- `ios-app-skeleton` — canonical blueprint `/init-ios-app` drives; a procedure spine plus file templates under `references/`, loaded step by step.

**MCP server**

- `figma` — Figma's official MCP server (`https://mcp.figma.com/mcp`), declared in `.mcp.json`. Used by `ios-ui-engineer` and the `swiftui-views` skill: supply a Figma URL when asking for a screen and the layout, typography, colour, and spacing come from the file rather than from guesswork. **Auth is OAuth in the browser on first use** — there's no API key in the plugin and nothing to configure. If you never pass a Figma URL, the server is never contacted.

## After installing

The plugin ships skills, agents, and commands. It does **not** inject a `CLAUDE.md` into your project automatically. Drop the included `CLAUDE.md` at your project root so Claude Code loads the project context on open:

```bash
# from your project root
cp <plugin-source>/CLAUDE.md ./CLAUDE.md
```

Edit the copy to reflect your app's specifics. The template is a starting point, not a lock-in.

## Updating

When a new version ships, reinstall via whichever tool you use:

```bash
# Claude Code
/plugin marketplace update cc-mobile

# Copilot CLI
/plugin update cc-mobile-ios
```

Your project's `CLAUDE.md` isn't touched by re-install — update it by hand when the template evolves.

## Building this plugin from source

From the `ClaudeCodeMobile/` repo root:

```bash
scripts/build-plugin.sh ios
```

The script reads `ios/.claude/{skills,agents,commands,hooks}` + `ios/.claude/hooks.json` + `ios/CLAUDE.md` and re-packages them, rewriting `.claude/…` config paths to `${CLAUDE_PLUGIN_ROOT}/…` so they resolve once installed. The hand-authored `plugin.json`, this README, `.mcp.json`, and `tests/` are preserved across rebuilds.

## Why these choices

See [ios/README.md](../../ios/README.md) in the source repo for the rationale (`@Observable` over `ObservableObject`, composition-root DI over a container, Swift Testing over XCTest for new code, `NavigationStack` over `NavigationView`).
