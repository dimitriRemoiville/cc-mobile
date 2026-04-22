# Claude Code — iOS / Swift / SwiftUI setup

This folder is a Claude Code configuration tailored for a native iOS app written in **Swift** with **SwiftUI**, using **MVVM + Clean Architecture**, `@Observable` view models, **Swift Concurrency**, and **URLSession**-based networking.

Drop this into the root of your iOS project (or start your project here), and Claude Code will pick up the agents, skills, and slash commands automatically.

## What's in here

```
CLAUDE.md                                  # Project context & conventions
.claude/
├── settings.json                          # Permissions
├── agents/                                # Specialist subagents
│   ├── ios-architect.md
│   ├── ios-ui-engineer.md
│   ├── ios-reviewer.md
│   ├── ios-tester.md
│   └── ios-build-expert.md
├── skills/                                # Domain knowledge packs
│   ├── swiftui-views/SKILL.md
│   ├── swift-style/SKILL.md
│   ├── clean-architecture-ios/SKILL.md
│   ├── ios-di/SKILL.md
│   ├── urlsession-networking/SKILL.md
│   └── ios-testing/SKILL.md
└── commands/                              # Slash commands
    ├── new-feature.md
    ├── add-view.md
    ├── add-usecase.md
    └── review-ios.md
```

## Agents — when each kicks in

| Agent | Use for |
|---|---|
| `ios-architect` | Module/layer decisions, where code belongs, trade-offs |
| `ios-ui-engineer` | Building or refactoring SwiftUI views & view models |
| `ios-reviewer` | Code review after changes, before PR |
| `ios-tester` | Writing unit, async, or UI tests |
| `ios-build-expert` | Swift Package Manager, build settings, Xcode project issues |

Claude Code will invoke these automatically based on the task, or you can call them explicitly via the `Task` tool.

## Skills — reference material

Skills are loaded on demand when the task matches. Each is a playbook the main agent (or a subagent) reads before acting on work in its area.

## Slash commands

- `/new-feature <name>` — scaffold a full feature across Data + Domain + Presentation.
- `/add-view <ViewName>` — add a SwiftUI view + view model + ViewState only.
- `/add-usecase <UseCaseName>` — add a use case with a test suite.
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
