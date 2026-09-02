# Reference — Tests

Unit tests for Feed + Profile ViewModels (JUnit + MockK + Turbine, no Robolectric) and androidTest Compose UI tests for the stateless screens. Loaded at execution-order step 9.

## `app/src/test/java/{{PACKAGE_PATH}}/feed/ui/FeedViewModelTest.kt`

Plain JUnit 4 + MockK + Turbine — no Robolectric. Mocks the use case + tracker and verifies both `init { }` side effects: (a) `Loading → Success` transition driven by the use case, and (b) `AnalyticsEvent.FeedViewed` firing exactly once.

```kotlin
package {{PACKAGE_ID}}.feed.ui

import app.cash.turbine.test
import io.mockk.coEvery
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsEvent
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsTracker
import {{PACKAGE_ID}}.feed.domain.model.FeedItem
import {{PACKAGE_ID}}.feed.domain.usecase.GetFeedUseCase

class FeedViewModelTest {
    @Before fun setup() { Dispatchers.setMain(UnconfinedTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    @Test
    fun `emits Success after init`() = runTest {
        val getFeed = mockk<GetFeedUseCase>()
        coEvery { getFeed() } returns Outcome.Success(listOf(FeedItem("1", "hello")))
        val analytics = mockk<AnalyticsTracker>(relaxed = true)

        val vm = FeedViewModel(getFeed, analytics)
        vm.state.test {
            assertEquals(
                FeedUiState.Success(listOf(FeedItem("1", "hello"))),
                awaitItem(),
            )
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `tracks FeedViewed on init`() {
        val getFeed = mockk<GetFeedUseCase>()
        coEvery { getFeed() } returns Outcome.Success(emptyList())
        val analytics = mockk<AnalyticsTracker>(relaxed = true)

        FeedViewModel(getFeed, analytics)

        verify(exactly = 1) { analytics.track(AnalyticsEvent.FeedViewed) }
    }
}
```

## `app/src/test/java/{{PACKAGE_PATH}}/profile/ui/ProfileViewModelTest.kt`

```kotlin
package {{PACKAGE_ID}}.profile.ui

import app.cash.turbine.test
import io.mockk.coEvery
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsEvent
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsTracker
import {{PACKAGE_ID}}.profile.domain.model.ProfileInfo
import {{PACKAGE_ID}}.profile.domain.usecase.GetProfileUseCase

class ProfileViewModelTest {
    @Before fun setup() { Dispatchers.setMain(UnconfinedTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    @Test
    fun `emits Success after init`() = runTest {
        val info = ProfileInfo(userName = "guest", email = "g@e.com", avatarUrl = null)
        val getProfile = mockk<GetProfileUseCase>()
        coEvery { getProfile() } returns Outcome.Success(info)
        val analytics = mockk<AnalyticsTracker>(relaxed = true)

        val vm = ProfileViewModel(getProfile, analytics)
        vm.state.test {
            assertEquals(ProfileUiState.Success(info), awaitItem())
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `tracks ProfileViewed on init`() {
        val getProfile = mockk<GetProfileUseCase>()
        coEvery { getProfile() } returns Outcome.Success(
            ProfileInfo("guest", "g@e.com", null),
        )
        val analytics = mockk<AnalyticsTracker>(relaxed = true)

        ProfileViewModel(getProfile, analytics)

        verify(exactly = 1) { analytics.track(AnalyticsEvent.ProfileViewed) }
    }
}
```

## `app/src/androidTest/java/{{PACKAGE_PATH}}/feed/ui/FeedScreenTest.kt`

A happy-path Compose UI test that proves the Route/Screen split is testable without Hilt. The test drives the **stateless** `FeedScreen` directly — that's the whole point of hoisting state out of the composable. `compose-ui` and `/add-screen` both mandate this shape; the scaffold ships it so subsequent screens have a working template to copy.

```kotlin
package {{PACKAGE_ID}}.feed.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import org.junit.Rule
import org.junit.Test
import {{PACKAGE_ID}}.core.ui.theme.AppTheme
import {{PACKAGE_ID}}.feed.domain.model.FeedItem

class FeedScreenTest {
    @get:Rule val composeRule = createComposeRule()

    @Test fun rendersItems() {
        composeRule.setContent {
            AppTheme {
                FeedScreen(
                    state = FeedUiState.Success(
                        items = listOf(
                            FeedItem("1", "alpha"),
                            FeedItem("2", "beta"),
                        ),
                    ),
                    onRetry = {},
                )
            }
        }
        composeRule.onNodeWithText("alpha").assertIsDisplayed()
        composeRule.onNodeWithText("beta").assertIsDisplayed()
    }
}
```

## `app/src/androidTest/java/{{PACKAGE_PATH}}/profile/ui/ProfileScreenTest.kt`

```kotlin
package {{PACKAGE_ID}}.profile.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import org.junit.Rule
import org.junit.Test
import {{PACKAGE_ID}}.core.ui.theme.AppTheme
import {{PACKAGE_ID}}.profile.domain.model.ProfileInfo

class ProfileScreenTest {
    @get:Rule val composeRule = createComposeRule()

    @Test fun rendersUserName() {
        composeRule.setContent {
            AppTheme {
                ProfileScreen(
                    state = ProfileUiState.Success(
                        ProfileInfo(userName = "Ada", email = "ada@example.com", avatarUrl = null),
                    ),
                    onRetry = {},
                )
            }
        }
        composeRule.onNodeWithText("Profile (Ada)").assertIsDisplayed()
    }
}
```
