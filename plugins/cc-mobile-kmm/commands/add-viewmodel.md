---
description: Add a shared ViewModel in commonMain with StateFlow<UiState> + UiEvent Channel + sealed Action.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /add-viewmodel $ARGUMENTS

Add a shared ViewModel in `shared/src/commonMain` under an existing feature. `$ARGUMENTS` is `<feature>/<Name>ViewModel`, e.g. `order/OrderViewModel`.

## Before writing any code

Read `${CLAUDE_PLUGIN_ROOT}/skills/shared-viewmodels/SKILL.md` and `${CLAUDE_PLUGIN_ROOT}/skills/kmm-ios-interop/SKILL.md`. The ViewModel is the most common iOS-facing surface — shape it so Swift callers don't suffer.

## What to produce

Four files in `shared/src/commonMain/kotlin/com/example/app/feature/<feature>/presentation/`:

1. `<Name>UiState.kt` — sealed interface of mutually exclusive states (`Loading`, `Success(...)`, `Error(...)`). Shallow, no generics. Initial state is not `null`.
2. `<Name>UiEvent.kt` — sealed interface of one-shot effects (`ShowToast`, `NavigateTo...`). Only things that should fire once per emission.
3. `<Name>Action.kt` — sealed interface of UI interactions (`Load`, `Submit(draft)`, `Retry`).
4. `<Name>ViewModel.kt` — extends `androidx.lifecycle.ViewModel` (multiplatform variant):
   ```kotlin
   class <Name>ViewModel(
       private val /* use cases */,
   ) : ViewModel() {
       private val _state = MutableStateFlow<<Name>UiState>(<Name>UiState.Loading)
       val state: StateFlow<<Name>UiState> = _state.asStateFlow()

       private val _events = Channel<<Name>UiEvent>(Channel.BUFFERED)
       val events: Flow<<Name>UiEvent> = _events.receiveAsFlow()

       fun onAction(action: <Name>Action) {
           when (action) { /* exhaustive */ }
       }
   }
   ```

## Wire-up

- Register in the feature's presentation module: `factory { (params) -> <Name>ViewModel(get(), ...) }`.
- Expose a `make<Name>ViewModel(...)` factory in `commonMain/di/AppKoin.kt` or the presentation module so Swift can call `AppKoinKt.make<Name>ViewModel(...)` without touching Koin.

## Tests

Add `shared/src/commonTest/.../presentation/<Name>ViewModelTest.kt` following `${CLAUDE_PLUGIN_ROOT}/skills/kmm-testing/SKILL.md`:
- `StandardTestDispatcher` set via `Dispatchers.setMain` in `@BeforeTest`, reset in `@AfterTest`.
- `runTest(dispatcher) { }` drives coroutines.
- Cover each action → state transition. Use `advanceUntilIdle()` then assert on `vm.state.value`.

## iOS interop checklist

Before finishing, confirm for the public surface (UiState / UiEvent / Action / ViewModel):
- No `inline` modifiers.
- No default arguments on public functions — supply overloads if needed.
- Sealed hierarchies are shallow and non-generic.
- Throwing suspends have `@Throws(...)`.
- No `internal` types leaking through public signatures.
