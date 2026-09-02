# Reference — tests

Swift Testing suites for both library targets — one pure-domain test over `Outcome`, one `@MainActor` view-model test. They exist to prove the package is testable from `swift test` without a simulator, not to reach coverage targets. Loaded at execution-order step 6.

### `Tests/AppCoreTests/OutcomeTests.swift`

```swift
import Testing
@testable import AppCore

@Suite struct OutcomeTests {
    @Test func mapTransformsSuccess() {
        let out = Outcome<Int>.success(2).map { $0 * 3 }
        switch out {
        case .success(let v): #expect(v == 6)
        case .failure: Issue.record("expected success")
        }
    }

    @Test func mapPreservesFailure() {
        let out = Outcome<Int>.failure(.notFound).map { $0 * 3 }
        switch out {
        case .success: Issue.record("expected failure")
        case .failure(let e): #expect(e == .notFound)
        }
    }
}
```

### `Tests/AppFeaturesTests/SplashViewModelTests.swift`

```swift
import Testing
import Foundation
@testable import AppFeatures

@MainActor
@Suite struct SplashViewModelTests {
    @Test func exposesDisplayName() {
        let vm = SplashViewModel(displayName: "{{APP_DISPLAY_NAME}}")
        #expect(vm.message == "{{APP_DISPLAY_NAME}}")
    }
}
```
