---
description: Add a single Compose screen with its ViewModel, UiState, preview, and a happy-path Compose UI test — no backend plumbing.
argument-hint: <ScreenName> [feature-package] [--no-test]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

Add a new Compose screen named **$ARGUMENTS**. This command is for presentation-layer-only work — no new repository, use case, or API.

Steps:

1. Read `.claude/skills/compose-ui/SKILL.md`, `.claude/skills/android-accessibility/SKILL.md`, and the nearest existing screen in the project for structural reference.
2. Figure out where the screen belongs. The project uses **feature-first** packaging (`<feature>/ui/`) per `android-architecture` and `android-app-skeleton`. If the user named a feature package, put it there; otherwise ask. Don't drop screens into a global `ui/` next to features — that's the layer-first shape we deliberately avoid.
3. Create these files — the canonical shape:

   ```
   <feature>/ui/
   ├── <Screen>UiState.kt       # sealed interface with Loading/Error/Success
   ├── <Screen>ViewModel.kt     # @HiltViewModel, StateFlow<UiState>; fires screen-viewed analytics in init { }
   ├── <Screen>Screen.kt        # Route + stateless Screen + Preview(s)
   ```

   The ViewModel exposes **discrete public functions** for user actions (`fun retry()`, `fun submit(draft: …)`), matching Google's [Now in Android](https://github.com/android/nowinandroid) and the official MVVM guidance. The Composable takes one lambda per action (`onRetry: () -> Unit`, `onSubmit: (Draft) -> Unit`).

   **Escalate to a sealed `<Screen>Action.kt`** only when the screen genuinely has ≥5 distinct interactions and the Composable signature would otherwise balloon — at that point a single `onAction: (Action) -> Unit` is cleaner. That's an MVI shape; this project is MVVM by default.

   If the feature already owns a `<Feature>Route.kt`, reuse it; only create a new `@Serializable` route file when you're adding a new destination class.

4. Wire it into the top-level NavGraph (`core/navigation/AppNavGraph.kt`). If the screen is a tab inside the bottom-nav shell, wire it into `home/ui/HomeScreen.kt`'s nested `NavHost` instead. The navigation API uses typed `@Serializable` routes.
5. At least one `@Preview` with a representative state — use `PreviewParameterProvider` if there are multiple distinct states worth seeing.
6. **Analytics.** Inject `AnalyticsTracker` as a `private val` and fire the screen-viewed event from the ViewModel's `init { }` block — this is the project's single canonical pattern (`feed/ui/FeedViewModel.kt` and `profile/ui/ProfileViewModel.kt` in the scaffold are the references). Don't expose `analytics` publicly to fire it from the Composable.
7. **Accessibility.** Every interactive node has a `contentDescription` or semantic role; tap targets ≥ 48dp; respect Dynamic Type and RTL. See `android-accessibility`.
8. **Add a Compose UI test** unless `--no-test` was passed. Place it at `app/src/androidTest/java/.../<Screen>ScreenTest.kt`. Cover the happy path (`Success` state renders the expected text/widgets). Use `createComposeRule()` and assert via semantic matchers (`onNodeWithText`, `onNodeWithContentDescription`) — see `android-testing` skill. Test the stateless `<Screen>Screen` composable directly, not the Route — that keeps the test free of Hilt and ViewModel setup.

   ```kotlin
   class <Screen>ScreenTest {
       @get:Rule val composeRule = createComposeRule()

       @Test fun `renders Success state`() {
           composeRule.setContent {
               AppTheme {
                   <Screen>Screen(
                       state = <Screen>UiState.Success(/* representative data */),
                       onRetry = {},
                   )
               }
           }
           composeRule.onNodeWithText("<expected text>").assertIsDisplayed()
       }
   }
   ```

   For non-trivial test setup, delegate to `android-tester` via the `Task` tool.

9. Verify: `./gradlew :app:assembleDebug` (and `./gradlew :app:connectedDebugAndroidTest --tests '*<Screen>ScreenTest*'` if an emulator is attached; otherwise flag the test as ready-to-run and stop).
10. Report the files you created, the route you added, and any next steps (e.g. "hook up the real repository call").

Consider delegating the UI work to the `android-ui-engineer` subagent via the Task tool, especially for non-trivial screens.
