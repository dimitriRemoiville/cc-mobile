---
name: android-architecture
description: How MVVM + Clean Architecture is applied in this Kotlin + Compose codebase — the project-specific deltas on top of [the official Architecture guide](https://developer.android.com/topic/architecture) and [Now in Android](https://github.com/android/nowinandroid). Load when designing a new feature, deciding where code belongs, adding a repository or use case, or reviewing layer boundaries. Not for apps using MVI, layer-first packaging, or non-Clean architectures.
---

# Android architecture (project delta)

For UI / Domain / Data layer fundamentals — what each layer is for, UDF, repositories, state holders — read the [official Architecture guide](https://developer.android.com/topic/architecture). This file documents only this project's specific choices on top of that.

## When this applies

This skill assumes **MVVM + Clean + Hilt + Retrofit + Room + feature-first packaging** — the shape `/init-android-app` scaffolds. On an existing app that already chose differently, defer:

- **MVI** (sealed `Action`/`Intent`/`Reducer`, single `dispatch(action)` entry point, Mavericks/Orbit) → keep it. Don't push "discrete public functions on the ViewModel."
- **Layer-first** (top-level `ui/`, `domain/`, `data/` with features nested under each) → also valid; don't migrate.
- **MVP / MVC / VIPER / Redux-style stores** → out of scope.

Surface the mismatch (`This project is MVI, applying clean-boundary guidance only`) and apply only the framework-agnostic principles: dependency direction, framework-free domain, errors-as-values at the boundary.

## Layer + dependency rule

```
ui        ─ Compose + ViewModel + UiState. Knows Android & Compose.
   ↓
domain    ─ Pure Kotlin. Business rules. No Android, Compose, Retrofit, Room.
   ↑
data      ─ Repository implementations. Knows Retrofit, Room, DataStore.
```

**`ui → domain ← data`. Arrows never reverse.** Both outer layers depend on `domain`; `domain` depends on nothing but Kotlin + coroutines. The reviewer flags `android.*` / Compose / Retrofit / Room imports inside any `domain/` package.

## Feature-first, not global (project choice)

The three layers live **inside each feature**: `<feature>/ui/`, `<feature>/domain/`, `<feature>/data/`. **No global `ui/`, `domain/`, `data/` at the package root.** Cross-feature plumbing — analytics interfaces, network factory, `Outcome` / `DomainError` types, theme, top-level nav — sits under `core/{ui,domain,data,navigation}/`.

We use `ui/` (not `presentation/`) — fewer letters, matches `core/ui/theme/`.

The canonical Feed and Profile features in `${CLAUDE_PLUGIN_ROOT}/skills/android-app-skeleton/references/feed-feature.md` / `profile-feature.md` are the working examples — clone their shape when adding the next feature.

## Errors as values

**Domain-facing signatures return `Outcome<T>`, never `Result<T>` and never raw `throw`.** Sealed type defined once in `core/domain/Outcome.kt`; matching `DomainError` taxonomy in `core/domain/DomainError.kt`. Repositories map exceptions to `DomainError` at the boundary via:

```kotlin
runCatching { api.getOrder(id.raw).toDomain() }.toOutcome(::toDomainError)
```

The `toOutcome` adapter lives in `core/data/network/Outcomes.kt` (see `kotlin-style` for the rule and rationale). Open-coding `runCatching { ... }.fold(...)` silently swallows `CancellationException` — the reviewer flags this every time.

## User actions are discrete VM functions

```kotlin
fun submit(draft: OrderDraft) { ... }
fun retry() { ... }
```

The Composable takes one lambda per action — the shape [Now in Android](https://github.com/android/nowinandroid) uses, and the canonical MVVM shape. Escalate to a sealed `UiAction` + a single `onAction(action: UiAction)` callback only when the screen has ≥5 distinct interactions and the flat surface is unwieldy. That's an MVI shape; this project is MVVM by default.

## When to add a use case

**Add one when:**
- There's business logic (validation, composition of multiple repositories, derived computation).
- Multiple ViewModels will call the same operation.
- The operation has testable branches that aren't interesting to test via a ViewModel.

**Skip it when:**
- The VM would literally just call `repository.foo()` and return. Inject the repository directly in that case, but only if the codebase is consistent about it.

[Now in Android](https://github.com/android/nowinandroid) takes the same posture — it uses use cases mainly to **combine multi-repo streams** (`GetUserNewsResourcesUseCase` combines `NewsResource` + `UserData`), and single-repo passthrough goes VM → repository directly.

## Module or package?

- **Start with packages** inside `:app`, feature-first. No extra `build.gradle.kts` until you actually need build-time isolation.
- **Promote to modules** when a feature has its own team, or you want compile-time enforcement of `domain/` being Android-free (a `kotlin.jvm` module makes the layer rule a compile error, not a review comment). Common split: `:core:domain`, `:core:data`, `:feature:orders`.
- Feature-first **packages** promote cleanly to feature-first **modules** — that's the main reason to start this way.
- Don't over-modularize early — module boundaries are expensive to rearrange.

## Feature checklist

When adding a feature, every item below should exist:

- [ ] Domain model in `<feature>/domain/model/`
- [ ] Repository interface in `<feature>/domain/repository/` (returns `Outcome<T>`)
- [ ] Use case(s) in `<feature>/domain/usecase/` (if warranted — see above)
- [ ] DTO in `<feature>/data/remote/` with colocated `toDomain()` mapper
- [ ] Retrofit service method in `<feature>/data/remote/`
- [ ] RepositoryImpl in `<feature>/data/repository/` (uses `toOutcome(::toDomainError)`; never open-coded `runCatching.fold`)
- [ ] Hilt `@Module` in `<feature>/data/di/`
- [ ] UiState + (optionally UiAction) + UiEvent in `<feature>/ui/`
- [ ] ViewModel with `@HiltViewModel`
- [ ] Route + Screen composables + at least one `@Preview`
- [ ] Nav destination wired in (`core/navigation/AppNavGraph.kt`)
- [ ] Unit tests for use case, mapper (if extracted), ViewModel
- [ ] Compose UI test for the screen (at least happy path)
