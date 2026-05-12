---
description: Add a single Compose screen with its ViewModel, UiState, preview, and a happy-path Compose UI test — no backend plumbing.
argument-hint: <ScreenName> [feature-package] [--no-test]
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
6. **Add a Compose UI test** unless `--no-test` was passed. Place it at `app/src/androidTest/java/.../<Screen>Test.kt`. Cover the happy path (`Success` state renders the expected text/widgets). Use `createComposeRule()` and assert via semantic matchers (`onNodeWithText`, `onNodeWithContentDescription`) — see `android-testing` skill, "Compose UI tests" section. Stateless `<Screen>` is what you test, not the Route — that keeps the test free of Hilt and ViewModel setup.

   Skeleton:
   ```kotlin
   class <Screen>Test {
       @get:Rule val composeRule = createComposeRule()

       @Test fun `renders Success state`() {
           composeRule.setContent {
               AppTheme {
                   <Screen>(
                       state = <Screen>UiState.Success(/* representative data */),
                       onAction = {},
                   )
               }
           }
           composeRule.onNodeWithText("<expected text>").assertIsDisplayed()
       }
   }
   ```
   For non-trivial test setup, delegate to `android-tester` via the `Task` tool.

7. Verify: `./gradlew :app:assembleDebug` (and `./gradlew :app:connectedDebugAndroidTest --tests '*<Screen>Test*'` if an emulator is attached; otherwise flag the test as ready-to-run and stop).
8. Report the files you created, the route you added, and any next steps (e.g. "hook up the real repository call").

Consider delegating the UI work to the `android-ui-engineer` subagent via the Task tool, especially for non-trivial screens.
