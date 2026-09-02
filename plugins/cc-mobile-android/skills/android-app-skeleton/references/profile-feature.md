# Reference — Profile feature

Mirrors Feed's three-layer shape. The repository returns a stub `ProfileInfo` wrapped in `Outcome.Success`; the screen renders the avatar via Coil's `AsyncImage` to demonstrate the end-to-end Coil wiring. Loaded at execution-order step 8.

## `app/src/main/java/{{PACKAGE_PATH}}/profile/domain/model/ProfileInfo.kt`

```kotlin
package {{PACKAGE_ID}}.profile.domain.model

data class ProfileInfo(
    val userName: String,
    val email: String,
    val avatarUrl: String?,
)
```

## `app/src/main/java/{{PACKAGE_PATH}}/profile/domain/repository/ProfileRepository.kt`

```kotlin
package {{PACKAGE_ID}}.profile.domain.repository

import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.profile.domain.model.ProfileInfo

interface ProfileRepository {
    suspend fun getProfile(): Outcome<ProfileInfo>
}
```

## `app/src/main/java/{{PACKAGE_PATH}}/profile/domain/usecase/GetProfileUseCase.kt`

```kotlin
package {{PACKAGE_ID}}.profile.domain.usecase

import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.profile.domain.model.ProfileInfo
import {{PACKAGE_ID}}.profile.domain.repository.ProfileRepository
import javax.inject.Inject

class GetProfileUseCase @Inject constructor(
    private val repository: ProfileRepository,
) {
    suspend operator fun invoke(): Outcome<ProfileInfo> = repository.getProfile()
}
```

## `app/src/main/java/{{PACKAGE_PATH}}/profile/data/repository/ProfileRepositoryImpl.kt`

```kotlin
package {{PACKAGE_ID}}.profile.data.repository

import {{PACKAGE_ID}}.core.domain.Outcome
import {{PACKAGE_ID}}.profile.domain.model.ProfileInfo
import {{PACKAGE_ID}}.profile.domain.repository.ProfileRepository
import javax.inject.Inject

class ProfileRepositoryImpl @Inject constructor() : ProfileRepository {
    // Stub data — replace with real source (Retrofit + RemoteDataSource or DataStore).
    override suspend fun getProfile(): Outcome<ProfileInfo> = Outcome.Success(
        ProfileInfo(
            userName = "guest",
            email = "guest@example.com",
            avatarUrl = null,
        ),
    )
}
```

## `app/src/main/java/{{PACKAGE_PATH}}/profile/data/di/ProfileDataModule.kt`

```kotlin
package {{PACKAGE_ID}}.profile.data.di

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import {{PACKAGE_ID}}.profile.data.repository.ProfileRepositoryImpl
import {{PACKAGE_ID}}.profile.domain.repository.ProfileRepository

@Module
@InstallIn(SingletonComponent::class)
abstract class ProfileDataModule {
    @Binds
    abstract fun bindProfileRepository(impl: ProfileRepositoryImpl): ProfileRepository
}
```

## `app/src/main/java/{{PACKAGE_PATH}}/profile/ui/ProfileUiState.kt`

```kotlin
package {{PACKAGE_ID}}.profile.ui

import {{PACKAGE_ID}}.profile.domain.model.ProfileInfo

sealed interface ProfileUiState {
    data object Loading : ProfileUiState
    data class Error(val message: String) : ProfileUiState
    data class Success(val profile: ProfileInfo) : ProfileUiState
}
```

## `app/src/main/java/{{PACKAGE_PATH}}/profile/ui/ProfileRoute.kt`

```kotlin
package {{PACKAGE_ID}}.profile.ui

import kotlinx.serialization.Serializable

@Serializable data object ProfileRoute
```

## `app/src/main/java/{{PACKAGE_PATH}}/profile/ui/ProfileViewModel.kt`

```kotlin
package {{PACKAGE_ID}}.profile.ui

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
import {{PACKAGE_ID}}.profile.domain.usecase.GetProfileUseCase
import javax.inject.Inject

@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val getProfile: GetProfileUseCase,
    private val analytics: AnalyticsTracker,
) : ViewModel() {
    private val _state = MutableStateFlow<ProfileUiState>(ProfileUiState.Loading)
    val state: StateFlow<ProfileUiState> = _state.asStateFlow()

    init {
        analytics.track(AnalyticsEvent.ProfileViewed)
        load()
    }

    fun retry() {
        load()
    }

    private fun load() {
        _state.value = ProfileUiState.Loading
        viewModelScope.launch {
            _state.value = when (val result = getProfile()) {
                is Outcome.Success -> ProfileUiState.Success(result.value)
                is Outcome.Failure -> ProfileUiState.Error(result.error::class.simpleName ?: "Unknown")
            }
        }
    }
}
```

## `app/src/main/java/{{PACKAGE_PATH}}/profile/ui/ProfileScreen.kt`

Same Route + Screen + Preview shape as Feed. The `AsyncImage` demonstrates Coil 3 end-to-end — `model = null` in the stub renders an empty placeholder, no network round-trip required. Coil's network fetcher reuses the project's `OkHttpClient` because `{{APP_CLASS}}` registered an `OkHttpNetworkFetcherFactory` (see "Application" above).

```kotlin
package {{PACKAGE_ID}}.profile.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import {{PACKAGE_ID}}.core.ui.theme.AppTheme
import {{PACKAGE_ID}}.profile.domain.model.ProfileInfo

@Composable
fun ProfileRoute(viewModel: ProfileViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    ProfileScreen(state = state, onRetry = viewModel::retry)
}

@Composable
fun ProfileScreen(
    state: ProfileUiState,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    when (state) {
        ProfileUiState.Loading -> Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        is ProfileUiState.Error -> Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Button(onClick = onRetry) {
                Text("Retry (${state.message})")
            }
        }
        is ProfileUiState.Success -> Column(
            modifier = modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            AsyncImage(
                model = state.profile.avatarUrl,
                contentDescription = null,
                modifier = Modifier
                    .size(96.dp)
                    .clip(CircleShape),
            )
            Text("Profile (${state.profile.userName})")
            Text(state.profile.email)
        }
    }
}

@Preview
@Composable
private fun ProfileScreenSuccessPreview() = AppTheme {
    ProfileScreen(
        state = ProfileUiState.Success(
            ProfileInfo(userName = "guest", email = "guest@example.com", avatarUrl = null),
        ),
        onRetry = {},
    )
}

@Preview
@Composable
private fun ProfileScreenLoadingPreview() = AppTheme {
    ProfileScreen(state = ProfileUiState.Loading, onRetry = {})
}

@Preview
@Composable
private fun ProfileScreenErrorPreview() = AppTheme {
    ProfileScreen(state = ProfileUiState.Error("Network"), onRetry = {})
}
```
