---
description: Scaffold a new feature across data, domain, and presentation in the shared module.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /new-feature $ARGUMENTS

Scaffold a new feature in the shared KMP module. `$ARGUMENTS` is the feature name in kebab-case (e.g. `order-detail`, `wishlist`).

## Before writing any code

1. Read the relevant skills so the scaffold matches conventions:
   - `.claude/skills/kmm-architecture/SKILL.md`
   - `.claude/skills/shared-viewmodels/SKILL.md`
   - `.claude/skills/koin-di/SKILL.md`
   - `.claude/skills/ktor-multiplatform/SKILL.md` (if the feature hits the network)
   - `.claude/skills/kmm-ios-interop/SKILL.md` (review the reviewer checklist before exposing new types)
2. Confirm the feature name and any external API it talks to. If unclear, ask.

## Layout to create

Convert `$ARGUMENTS` to a Kotlin-safe package segment (kebab → snake or camel per existing neighbours). Call the segment `<feature>`.

```
shared/src/commonMain/kotlin/com/example/app/feature/<feature>/
├── data/
│   ├── <Feature>RepositoryImpl.kt
│   ├── remote/
│   │   ├── <Feature>Api.kt
│   │   └── <Feature>Dto.kt
│   └── di/<feature>DataModule.kt
├── domain/
│   ├── <Feature>.kt                    # domain model(s)
│   ├── <Feature>Repository.kt          # interface
│   └── usecase/Get<Feature>UseCase.kt
└── presentation/
    ├── <Feature>ViewModel.kt
    ├── <Feature>UiState.kt             # sealed interface
    ├── <Feature>UiEvent.kt             # sealed interface
    ├── <Feature>Action.kt              # sealed interface
    └── di/<feature>PresentationModule.kt
```

Tests (mirror under `commonTest`):

```
shared/src/commonTest/kotlin/com/example/app/feature/<feature>/
├── domain/usecase/Get<Feature>UseCaseTest.kt
├── data/<Feature>RepositoryImplTest.kt     # MockEngine
└── presentation/<Feature>ViewModelTest.kt
```

## Wire up DI

- Add both new modules to `initKoin(...)` in `shared/src/commonMain/kotlin/com/example/app/di/AppKoin.kt`.
- Keep platform-specific bindings out of these modules — they belong in `androidPlatformModule` / `iosPlatformModule`.

## After scaffolding

- Run `./gradlew :shared:allTests` and fix any failures.
- If this feature exposes new public types to iOS, walk the `kmm-ios-interop` reviewer checklist (no `inline`, no default args, shallow sealed hierarchies, `@Throws` on throwing suspends).
- Mention how the Android and iOS app modules should consume the new ViewModel (via `koinViewModel { parametersOf(...) }` on Android; via a `make<Feature>ViewModel(...)` bridging helper on iOS).
