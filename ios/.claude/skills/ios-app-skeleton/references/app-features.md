# Reference — `Sources/AppFeatures/`

The Splash feature in its full container / presentational shape, plus the typed navigation destinations. This is the pattern every later feature copies: a stateless `View`, an `@Observable @MainActor` view model, a `Root` container that owns the model, and at least one `#Preview`. Loaded at execution-order step 4.

### `Splash/SplashView.swift`

```swift
import SwiftUI

public struct SplashView: View {
    @State private var viewModel: SplashViewModel

    public init(viewModel: SplashViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack {
            Text(viewModel.message)
                .font(.largeTitle)
                .bold()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(viewModel.message))
    }
}

#Preview {
    SplashView(viewModel: SplashViewModel(displayName: "{{APP_DISPLAY_NAME}}"))
}
```

### `Splash/SplashViewModel.swift`

```swift
import Foundation
import Observation

@Observable
@MainActor
public final class SplashViewModel {
    public private(set) var message: String

    public init(displayName: String) {
        self.message = displayName
    }
}
```

### `Navigation/Destination.swift`

```swift
import SwiftUI

public enum Destination: Hashable {
    case splash
}

public struct AppNavigation: View {
    @State private var path = NavigationPath()

    public init() {}

    public var body: some View {
        NavigationStack(path: $path) {
            SplashView(viewModel: SplashViewModel(displayName: "{{APP_DISPLAY_NAME}}"))
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .splash:
                        SplashView(viewModel: SplashViewModel(displayName: "{{APP_DISPLAY_NAME}}"))
                    }
                }
        }
    }
}
```
