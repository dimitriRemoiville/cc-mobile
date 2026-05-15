# Claude Code — iOS / Swift / SwiftUI setup

This folder is a Claude Code configuration tailored for a native iOS app written in **Swift** with **SwiftUI**, using **MVVM + Clean Architecture**, `@Observable` view models, **Swift Concurrency**, and **URLSession**-based networking.

Drop this into the root of your iOS project (or start your project here), and Claude Code will pick up the agents, skills, and slash commands automatically.

## What's in here

```
CLAUDE.md                                  # Project context & conventions
.claude/
├── settings.json                          # Permissions
├── hooks.json                             # PostToolUse + PreToolUse hook wiring
├── hooks/                                 # Versioned hook scripts
│   ├── format.sh                          # swiftformat + swiftlint --fix on edited files
│   └── pre-commit.sh                      # swiftlint --strict + swift build before `git commit`
├── agents/                                # Specialist subagents
│   ├── ios-architect.md
│   ├── ios-ui-engineer.md
│   ├── ios-reviewer.md
│   ├── ios-tester.md
│   ├── ios-build-expert.md
│   ├── ios-security-reviewer.md
│   ├── ios-a11y-reviewer.md
│   ├── ios-performance-analyst.md
│   └── ios-release-engineer.md
├── skills/                                # Domain knowledge packs
│   ├── ios-architecture/SKILL.md
│   ├── ios-app-skeleton/SKILL.md
│   ├── ios-accessibility/SKILL.md
│   ├── ios-di/SKILL.md
│   ├── ios-performance/SKILL.md
│   ├── ios-release/SKILL.md               # focused release-time playbook (preloaded by ios-release-engineer)
│   ├── ios-security/SKILL.md
│   ├── ios-testing/SKILL.md
│   ├── keychain-secure-storage/SKILL.md
│   ├── navigation-stack/SKILL.md
│   ├── swift-concurrency/SKILL.md
│   ├── swift-style/SKILL.md
│   ├── swiftdata-persistence/SKILL.md
│   ├── swiftui-views/SKILL.md
│   └── urlsession-networking/SKILL.md
└── commands/                              # Slash commands
    ├── init-ios-app.md
    ├── new-feature.md
    ├── add-view.md
    ├── add-usecase.md
    ├── add-migration.md
    ├── review-ios.md
    ├── upgrade-deps.md
    └── fix-tests.md
```

## Agents — when each kicks in

| Agent | Use for |
|---|---|
| `ios-architect` | Module/layer decisions, where code belongs, trade-offs |
| `ios-ui-engineer` | Building or refactoring SwiftUI views & view models |
| `ios-reviewer` | Code review after changes, before PR |
| `ios-tester` | Writing unit, async, or UI tests |
| `ios-build-expert` | Swift Package Manager, build settings, Xcode project issues |
| `ios-security-reviewer` | Auth, Keychain, ATS, URLSession, WebView, Info.plist permission strings |
| `ios-a11y-reviewer` | VoiceOver labels/traits, Dynamic Type, contrast, hit-target sizing |
| `ios-performance-analyst` | Cold start, scroll jank, memory growth, Instruments / signpost analysis |
| `ios-release-engineer` | Version bumps, signing, App Store Connect metadata, fastlane / `xcodebuild archive` |

Claude Code will invoke these automatically based on the task, or you can call them explicitly via the `Task` tool.

## Skills — reference material

Skills are loaded on demand when the task matches. Each is a playbook the main agent (or a subagent) reads before acting on work in its area.

## Slash commands

- `/init-ios-app [bundle_id]` — scaffold a brand-new iOS app from scratch (Swift 6, SwiftUI, SPM, composition-root DI, Keychain, NavigationStack with typed destinations, Swift Testing). Verifies the Swift/Xcode toolchain floor and resolves any third-party SPM tags online.
- `/new-feature <name>` — scaffold a full feature across Data + Domain + Presentation.
- `/add-view <ViewName>` — add a SwiftUI view + view model + ViewState only.
- `/add-usecase <UseCaseName>` — add a use case with a test suite.
- `/add-migration <name>` — add a SwiftData schema migration.
- `/upgrade-deps` — refresh SPM tags against the GitHub Releases API.
- `/fix-tests` — investigate + fix failing tests on the current branch.
- `/review-ios` — delegate a review pass to `ios-reviewer` on the current branch.

## Opinionated choices

The agents and skills assume:
- **Swift 6** with strict concurrency.
- **iOS 17+** (to use `@Observable` and modern SwiftUI APIs).
- **MVVM + Clean Architecture** (Presentation / Domain / Data).
- **`@Observable` view models**, not `ObservableObject`.
- **Composition root + initializer injection** for DI (no container library).
- **URLSession + Codable**, not Alamofire or Moya.
- **Swift Testing** for unit/integration, **XCTest** for UI automation.

If your project needs different choices (older iOS, TCA, a DI library, Alamofire), edit the `CLAUDE.md` and the relevant skills — the agents read those on every task.

## Next steps

1. Drop this into your iOS project root (or initialize an Xcode project here).
2. Open it in Claude Code — run `/help` to confirm the commands and agents are registered.
3. Try `/new-feature settings` or `/add-view ProfileView` to smoke-test the setup.
