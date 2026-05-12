---
description: Add a single Compose screen with its ViewModel, UiState, preview, and a happy-path Compose UI test — no backend plumbing.
argument-hint: <ScreenName> [feature-package] [--no-test]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

Add a new Compose screen named **$ARGUMENTS**. This command is for presentation-layer-only work — no new repository, use case, or API.

Steps:

1. Read `.claude/skills/compose-ui/SKILL.md` and the nearest existing screen in the project for structural reference.
2. Figure out where the screen belongs. The project uses **feature-first** packaging (`<feature>/ui/`) per `android-architecture` and `android-app-skeleton`. If the user named a feature package, put it there; otherwise ask. Don't drop screens into a global `ui/` next to features — that's the layer-first shape we deliberately avoid.
3. Create these files:

   ```
   <feature>/ui/
   ├── <Screen>UiState.kt       # sealed interface with Loading/Error/Success at minimum
   ├── <Screen>Action.kt        # user actions
   ├── <Screen>ViewModel.kt     # @HiltViewModel, StateFlow<UiState>
   ├── <Screen>Screen.kt        # Route + stateless Screen + Preview(s)
   ```

4. Wire it into the top-level NavGraph (`core/navigation/AppNavGraph.kt`). If the screen is a tab inside the bottom-nav shell, wire it into `home/ui/HomeScreen.kt`'s nested `NavHost` instead. The navigation API uses typed `@Serializable` routes — define one for this destination.
5. At least one `@Preview` with a representative state — use `PreviewParameterProvider` if there are multiple distinct states worth seeing.
6. **Add a Compose UI test** unless `--no-test` was passed. Place it at `app/src/androidTest/java/.../<Screen>ScreenTest.kt`. Cover the happy path (`Success` state renders the expected text/widgets). Use `createComposeRule()` and assert via semantic matchers (`onNodeWithText`, `onNodeWithContentDescription`) — see `android-testing` skill, "Compose UI tests" section. The stateless `<Screen>Screen` composable is what you test, not the Route — that keeps the test free of Hilt and ViewModel setup.

   Skeleton (file name, class name, and called function name all share the `<Screen>Screen` shape — match them so the test matches the convention used everywhere else in the project):

   ```kotlin
   class <Screen>ScreenTest {
       @get:Rule val composeRule = createComposeRule()

       @Test fun `renders Success state`() {
           composeRule.setContent {
               AppTheme {
                   <Screen>Screen(
                       state = <Screen>UiState.Success(/* representative data */),
                       onAction = {},
                   )
               }
           }
           composeRule.onNodeWithText("<expected text>").assertIsDisplayed()
       }
   }
   ```

   The `Success` shape assumes a sealed `UiState` with Loading/Error/Success variants. If your screen has a single `data class` UiState, drive the test with that directly (see `feed/ui/FeedScreenTest.kt` in the scaffold for the simpler shape). For non-trivial test setup, delegate to `android-tester` via the `Task` tool.

7. Verify: `./gradlew :app:assembleDebug` (and `./gradlew :app:connectedDebugAndroidTest --tests '*<Screen>ScreenTest*'` if an emulator is attached; otherwise flag the test as ready-to-run and stop).
8. Report the files you created, the route you added, and any next steps (e.g. "hook up the real repository call").

Consider delegating the UI work to the `android-ui-engineer` subagent via the Task tool, especially for non-trivial screens.
