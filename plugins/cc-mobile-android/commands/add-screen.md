---
description: Add a single Compose screen with its ViewModel, UiState, and preview — no backend plumbing.
argument-hint: <ScreenName> [feature-package]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

Add a new Compose screen named **$ARGUMENTS**. This command is for presentation-layer-only work — no new repository, use case, or API.

Steps:

1. Read `.claude/skills/compose-ui/SKILL.md` and the nearest existing screen in the project for structural reference.
2. Figure out where the screen belongs. If the user named a feature package, put it there; otherwise ask.
3. Create these files:

   ```
   <feature>/presentation/<screen>/
   ├── <Screen>UiState.kt       # sealed interface with Loading/Error/Success at minimum
   ├── <Screen>Action.kt        # user actions
   ├── <Screen>ViewModel.kt     # @HiltViewModel, StateFlow<UiState>
   ├── <Screen>Screen.kt        # Route + stateless Screen + Preview(s)
   ```

4. Wire it into the NavGraph (update `MainNavGraph.kt` or equivalent). If the navigation API uses typed routes, define the route.
5. At least one `@Preview` with a representative state — use `PreviewParameterProvider` if there are multiple distinct states worth seeing.
6. Verify: `./gradlew :app:assembleDebug`.
7. Report the files you created, the route you added, and any next steps (e.g. "hook up the real repository call").

Consider delegating the UI work to the `android-ui-engineer` subagent via the Task tool, especially for non-trivial screens.
