# Reference — Feed feature

Full feature-first shape — `data/` + `domain/` + `ui/`. Repository returns hard-coded stub data wrapped in `Outcome.Success`; replace with a real source when wiring a backend. The structure matches what `/new-feature` produces so adding the next feature is a copy-paste of this layout. Loaded at execution-order step 8.

## `app/src/main/java/{{PACKAGE_PATH}}/feed/domain/model/FeedItem.kt`

```kotlin
package {{PACKAGE_ID}}.feed.domain.model

data class FeedItem(
    val id: String,
    val title: String,
)
```

## `app/src/main/java/{{PACKAGE_PATH}}/feed/domain/repository/FeedRepository.kt`

```kotlin
package {{PACKAGE_ID}}.feed.domain.repository

import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.feed.domain.model.FeedItem

interface FeedRepository {
    suspend fun getFeed(): Outcome<List<FeedItem>>
}
```

## `app/src/main/java/{{PACKAGE_PATH}}/feed/domain/usecase/GetFeedUseCase.kt`

```kotlin
package {{PACKAGE_ID}}.feed.domain.usecase

import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.feed.domain.model.FeedItem
import {{PACKAGE_ID}}.feed.domain.repository.FeedRepository
import javax.inject.Inject

class GetFeedUseCase @Inject constructor(
    private val repository: FeedRepository,
) {
    suspend operator fun invoke(): Outcome<List<FeedItem>> = repository.getFeed()
}
```

## `app/src/main/java/{{PACKAGE_PATH}}/feed/data/repository/FeedRepositoryImpl.kt`

```kotlin
package {{PACKAGE_ID}}.feed.data.repository

import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.feed.domain.model.FeedItem
import {{PACKAGE_ID}}.feed.domain.repository.FeedRepository
import javax.inject.Inject

class FeedRepositoryImpl @Inject constructor() : FeedRepository {
    // Stub data — replace with real source (Retrofit + RemoteDataSource or Room).
    override suspend fun getFeed(): Outcome<List<FeedItem>> = Outcome.Success(
        listOf(
            FeedItem(id = "1", title = "Welcome to your new app"),
            FeedItem(id = "2", title = "Edit FeedRepositoryImpl to wire a real source"),
            FeedItem(id = "3", title = "Tap retry to re-run the use case"),
        ),
    )
}
```

## `app/src/main/java/{{PACKAGE_PATH}}/feed/data/di/FeedDataModule.kt`

```kotlin
package {{PACKAGE_ID}}.feed.data.di

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import {{PACKAGE_ID}}.feed.data.repository.FeedRepositoryImpl
import {{PACKAGE_ID}}.feed.domain.repository.FeedRepository

@Module
@InstallIn(SingletonComponent::class)
abstract class FeedDataModule {
    @Binds
    abstract fun bindFeedRepository(impl: FeedRepositoryImpl): FeedRepository
}
```

## `app/src/main/java/{{PACKAGE_PATH}}/feed/ui/FeedUiState.kt`

```kotlin
package {{PACKAGE_ID}}.feed.ui

import {{PACKAGE_ID}}.feed.domain.model.FeedItem

sealed interface FeedUiState {
    data object Loading : FeedUiState
    data class Error(val message: String) : FeedUiState
    data class Success(val items: List<FeedItem>) : FeedUiState
}
```

## `app/src/main/java/{{PACKAGE_PATH}}/feed/ui/FeedRoute.kt`

The typed `@Serializable` destination consumed by `AppNavGraph` / `HomeScreen`. Lives inside the feature's `ui/` package so the nav graph imports it from `feed.ui` — never from `core/navigation/`.

```kotlin
package {{PACKAGE_ID}}.feed.ui

import kotlinx.serialization.Serializable

@Serializable data object FeedRoute
```

## `app/src/main/java/{{PACKAGE_PATH}}/feed/ui/FeedViewModel.kt`

Drives `Loading → Success/Error` from the use case, fires `AnalyticsEvent.FeedViewed` from `init { }` (canonical shape), exposes `retry()` as a discrete public function (no sealed `Action` — that's an MVI escalation, this project follows Google's Now in Android shape).

```kotlin
package {{PACKAGE_ID}}.feed.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsEvent
import {{PACKAGE_ID}}.core.domain.analytics.AnalyticsTracker
import {{PACKAGE_ID}}.feed.domain.usecase.GetFeedUseCase
import javax.inject.Inject

@HiltViewModel
class FeedViewModel @Inject constructor(
    private val getFeed: GetFeedUseCase,
    private val analytics: AnalyticsTracker,
) : ViewModel() {
    private val _state = MutableStateFlow<FeedUiState>(FeedUiState.Loading)
    val state: StateFlow<FeedUiState> = _state.asStateFlow()

    init {
        analytics.track(AnalyticsEvent.FeedViewed)
        load()
    }

    fun retry() {
        load()
    }

    private fun load() {
        _state.value = FeedUiState.Loading
        viewModelScope.launch {
            _state.value = when (val result = getFeed()) {
                is Outcome.Success -> FeedUiState.Success(result.value)
                is Outcome.Failure -> FeedUiState.Error(result.error::class.simpleName ?: "Unknown")
            }
        }
    }
}
```

## `app/src/main/java/{{PACKAGE_PATH}}/feed/ui/FeedScreen.kt`

Route + Screen split — the project's canonical Compose shape (see `compose-ui`):

- **`FeedRoute`** (the `@Composable` wrapper) owns the ViewModel via `hiltViewModel()` and forwards state to the stateless screen. Lives in this file alongside `FeedScreen` so the route + UI sit together; the `@Serializable FeedRoute` destination is the data object in `FeedRoute.kt`.
- **`FeedScreen`** takes state + callbacks. Pure UI, previewable, testable without Hilt.
- **`@Preview`** renders the stateless screen with sample data per UiState branch.

```kotlin
package {{PACKAGE_ID}}.feed.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import {{PACKAGE_ID}}.core.ui.theme.AppTheme
import {{PACKAGE_ID}}.feed.domain.model.FeedItem

@Composable
fun FeedRoute(viewModel: FeedViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    FeedScreen(state = state, onRetry = viewModel::retry)
}

@Composable
fun FeedScreen(
    state: FeedUiState,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    when (state) {
        FeedUiState.Loading -> Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        is FeedUiState.Error -> Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Button(onClick = onRetry) {
                Text("Retry (${state.message})")
            }
        }
        is FeedUiState.Success -> LazyColumn(
            modifier = modifier.fillMaxSize().padding(8.dp),
        ) {
            items(state.items, key = { it.id }) { item ->
                ListItem(headlineContent = { Text(item.title) })
            }
        }
    }
}

@Preview
@Composable
private fun FeedScreenSuccessPreview() = AppTheme {
    FeedScreen(
        state = FeedUiState.Success(
            items = listOf(
                FeedItem("1", "Hello"),
                FeedItem("2", "World"),
            ),
        ),
        onRetry = {},
    )
}

@Preview
@Composable
private fun FeedScreenLoadingPreview() = AppTheme {
    FeedScreen(state = FeedUiState.Loading, onRetry = {})
}

@Preview
@Composable
private fun FeedScreenErrorPreview() = AppTheme {
    FeedScreen(state = FeedUiState.Error("Network"), onRetry = {})
}
```
