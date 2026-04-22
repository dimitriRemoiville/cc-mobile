---
name: swiftui-views
description: Authoritative playbook for building SwiftUI views and view models in this project. Use whenever writing or editing any `View`, navigation destination, preview, or `@Observable` view model. Covers state ownership, the container / presentational split, navigation, accessibility, and previews.
---

# SwiftUI views skill

This skill governs every SwiftUI change in the project.

## Container / presentational split

A screen is split into two views:
- A **Root** view that owns the `@Observable` view model and knows about the world (routing, environment, etc.).
- A **stateless presentation** view that takes values + closures only.

```swift
// ProfileRootView.swift — stateful container
struct ProfileRootView: View {
    @State private var model: ProfileViewModel
    let onSelectPost: (PostID) -> Void

    init(
        userID: UserID,
        container: DIContainer,
        onSelectPost: @escaping (PostID) -> Void
    ) {
        _model = State(initialValue: container.makeProfileViewModel(userID: userID))
        self.onSelectPost = onSelectPost
    }

    var body: some View {
        ProfileView(
            state: model.state,
            onRefresh: { Task { await model.refresh() } },
            onSelectPost: onSelectPost
        )
        .task { await model.load() }
    }
}

// ProfileView.swift — pure UI, fully previewable
struct ProfileView: View {
    let state: ProfileViewState
    let onRefresh: () -> Void
    let onSelectPost: (PostID) -> Void

    var body: some View {
        switch state {
        case .loading:
            ProgressView().accessibilityLabel("Loading profile")
        case .error(let message):
            ErrorState(message: message, onRetry: onRefresh)
        case .loaded(let profile):
            ProfileContent(profile: profile, onSelectPost: onSelectPost)
        }
    }
}

#Preview("Loaded") {
    ProfileView(state: .loaded(.sample), onRefresh: {}, onSelectPost: { _ in })
}

#Preview("Error") {
    ProfileView(state: .error("Couldn't load"), onRefresh: {}, onSelectPost: { _ in })
}
```

## ViewState

Enum when states are distinct:

```swift
enum ProfileViewState: Equatable {
    case loading
    case loaded(Profile)
    case error(String)
}
```

Struct when the screen is always-populated and you need fields:

```swift
struct ComposeViewState: Equatable {
    var text: String = ""
    var isSending: Bool = false
    var errorMessage: String?
}
```

Never use the `@Observable` model itself as a view's "state" — always pass `model.state` to the presentation view.

## ViewModel

```swift
@Observable
@MainActor
final class ProfileViewModel {
    private(set) var state: ProfileViewState = .loading

    private let getProfile: GetProfileUseCase

    init(getProfile: GetProfileUseCase) {
        self.getProfile = getProfile
    }

    func load() async { /* ... */ }
    func refresh() async { await load() }
}
```

- `@Observable` + `@MainActor` + `final class`.
- `private(set)` on all mutable state.
- Constructor injection; collaborators are protocols.
- Methods are `async`; views wrap them in `Task { }` or `.task { }`.

## Navigation

Typed routes, value-based `NavigationStack`:

```swift
enum AppRoute: Hashable {
    case profile(UserID)
    case post(PostID)
    case settings
}

struct AppRootView: View {
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeRootView(onSelect: { path.append($0) })
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .profile(let id): ProfileRootView(userID: id, container: .live, onSelectPost: { path.append(.post($0)) })
                    case .post(let id): PostRootView(postID: id, container: .live)
                    case .settings: SettingsRootView()
                    }
                }
        }
    }
}
```

Rules:
- Destinations are values (`Hashable`), not `AnyView` factories.
- The root composes the nav graph. Individual screens don't know the whole graph — they receive callbacks for what they can navigate to.
- Deep links map to the same `AppRoute` type.

## Previews

Every non-trivial view has multiple previews covering distinct states. Wrap previews in any environment the view needs:

```swift
#Preview("Light") {
    ProfileView(state: .loaded(.sample), onRefresh: {}, onSelectPost: { _ in })
}

#Preview("Dark") {
    ProfileView(state: .loaded(.sample), onRefresh: {}, onSelectPost: { _ in })
        .preferredColorScheme(.dark)
}
```

`#Preview` blocks can return any `View`. Use sample data — never live network / SwiftData in previews.

## Accessibility

- `accessibilityLabel`, `accessibilityHint`, and `accessibilityValue` are the three knobs.
- Decorative images: `.accessibilityHidden(true)`.
- Group related controls with `.accessibilityElement(children: .combine)`.
- Test with VoiceOver once on every new screen.
- Support Dynamic Type — use `.font(.body)` / `.font(.headline)`, not fixed `.font(.system(size: 14))`.

## Performance

- Extract subviews. Apple's diffing engine benefits from small, stable view types.
- For lists: `List` or `LazyVStack` with identifiable data. Provide `id:` explicitly when the type isn't `Identifiable`.
- Use `@ViewBuilder` helpers for conditional subviews.
- `.task(id:)` cancels the previous task when `id` changes — use for per-item loading.
- Avoid `AnyView`; it erases type info and hurts diffing.

## Hard nos

- No `@Published` / `ObservableObject` in new code.
- No `DispatchQueue.main.async`; use `Task { @MainActor in … }` or mark the type `@MainActor`.
- No network / database calls inside a view's `body` or `onAppear`.
- No `#Preview` that requires real IO.
- No view whose `body` is longer than ~40 lines — extract.
