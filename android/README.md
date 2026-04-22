# Claude Code — Android / Kotlin / Compose setup

This folder is a Claude Code configuration tailored for a native Android app written in **Kotlin** with **Jetpack Compose**, using **MVVM + Clean Architecture**, **Hilt**, and **Retrofit**.

Drop this into the root of your Android project (or start your project here), and Claude Code will pick up the agents, skills, and slash commands automatically.

## What's in here

```
CLAUDE.md                                  # Project context & conventions
.claude/
├── settings.json                          # Permissions, env
├── agents/                                # Specialist subagents
│   ├── android-architect.md
│   ├── android-ui-engineer.md
│   ├── android-reviewer.md
│   ├── android-tester.md
│   └── android-build-expert.md
├── skills/                                # Domain knowledge packs
│   ├── compose-ui/SKILL.md
│   ├── kotlin-style/SKILL.md
│   ├── clean-architecture/SKILL.md
│   ├── hilt-di/SKILL.md
│   ├── retrofit-networking/SKILL.md
│   └── android-testing/SKILL.md
└── commands/                              # Slash commands
    ├── new-feature.md
    ├── add-screen.md
    ├── add-usecase.md
    └── review-android.md
```

## Agents — when each kicks in

| Agent | Use for |
|---|---|
| `android-architect` | Module/layer decisions, where code belongs, trade-offs |
| `android-ui-engineer` | Building or refactoring Compose screens & components |
| `android-reviewer` | Code review after changes, before PR |
| `android-tester` | Writing unit, Flow, or Compose UI tests |
| `android-build-expert` | Build files, version catalog, Hilt/KSP setup, build failures |

Claude Code will invoke these automatically based on the task, or you can call them explicitly via the `Task` tool.

## Skills — reference material

Skills are loaded on demand when the task matches. Each one is a playbook the main agent (or a subagent) reads before acting on work in its area.

## Slash commands

- `/new-feature <name>` — scaffold a full feature across data + domain + presentation.
- `/add-screen <ScreenName>` — add a Compose screen + ViewModel + UiState only.
- `/add-usecase <UseCaseName>` — add a use case with a unit test.
- `/review-android` — delegate a review pass to `android-reviewer` on the current branch.

## Next steps

1. Drop this into your Android project root (or initialize an Android project here).
2. Open it in Claude Code — run `/help` to confirm the commands and agents are registered.
3. Try `/new-feature settings` or `/add-screen ProfileScreen` to smoke-test the setup.

## Adding more stacks later

When you're ready to add iOS, web, or backend, create sibling Claude Code configs with their own `.claude/` directories — the structure here (CLAUDE.md + agents + skills + commands) is the template. Keep `CLAUDE.md` specific to that stack's conventions.
