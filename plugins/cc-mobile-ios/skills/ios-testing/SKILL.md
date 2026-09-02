---
name: ios-testing
description: Project-specific testing conventions on top of Swift Testing + XCTest UI automation — `Outcome` in stub returns, the `@MainActor` view-model suite shape, the full-state-sequence assertion rule, hand-rolled stubs vs fakes, and the `URLProtocol` network seam. Load when writing, updating, or debugging tests of any kind.
---

# Testing (project delta)

For testing fundamentals — `@Test` / `@Suite` / `#expect` / `#require` semantics, parameterised tests, traits, `XCUIApplication` querying — read [Apple's Swift Testing documentation](https://developer.apple.com/documentation/testing) and the [XCTest UI testing guide](https://developer.apple.com/documentation/xctest/user_interface_tests). This file documents only this project's conventions. The scaffolded seed suites live in `${CLAUDE_PLUGIN_ROOT}/skills/ios-app-skeleton/references/tests.md`.

## When this applies

**Swift Testing** for unit and integration, **XCTest** for UI automation, hand-rolled test doubles. On an existing app:

- **XCTest-only** (no `import Testing`, or an Xcode < 16 floor) → keep it. Write new tests in XCTest to match; the assertions differ, every rule below still applies.
- **Quick / Nimble** (`describe`, `it`, `expect(...).to(...)`) → keep the BDD style for that target rather than mixing two vocabularies in one file.
- **A mocking library** (Cuckoo, Mockingbird, generated mocks) → keep it. Don't hand-roll new doubles alongside generated ones.
- **Snapshot tests** (`swift-snapshot-testing`) → complementary, not a substitute for the view-model tests below. Note the recorded-reference maintenance cost when it's relevant.

## Two frameworks, split by kind

| Kind | Framework | Where |
|---|---|---|
| Domain, use cases, mappers, repositories | Swift Testing | `Tests/AppCoreTests/` |
| View models | Swift Testing, `@MainActor` suite | `Tests/AppFeaturesTests/` |
| UI / E2E | XCTest + `XCUIApplication` | `UITests/` |

Swift Testing doesn't cover UI automation, so UI tests stay XCTest. That's the only reason to write a new `XCTestCase`.

## `Outcome` in test doubles

Repository and use-case doubles return `Outcome.success(...)` / `.failure(DomainError.x)` — **not** `Result`, not a thrown error, unless the real signature throws. Matching the production signature is what makes the test exercise the real mapping path.

```swift
let orders = StubOrderRepository(result: .failure(.server(code: 500)))
```

## View-model suites

View models are `@MainActor`, so the suite is too:

```swift
@Suite @MainActor
struct ProfileViewModelTests {
    @Test func loadMovesFromLoadingToLoaded() async {
        let model = ProfileViewModel(getProfile: StubGetProfileUseCase(result: .success(.sample)))

        #expect(model.state == .loading)
        await model.load()
        #expect(model.state == .loaded(.sample))
    }
}
```

Two rules that catch real bugs:

- **Assert the whole state sequence the test cares about**, including the initial `.loading`, not just the final value. A view model that jumps straight to `.loaded` and never shows a spinner passes a final-value-only assertion.
- **Await the method under test.** There is no scheduler to advance here, but there is also no polling: `while model.state == .loading { }` in a test is always wrong.

## Stubs vs fakes

- **Stub** — returns a scripted answer, ignores input. Default choice for a one- or two-method protocol.
- **Fake** — working in-memory behaviour. Worth it once a protocol has more than two methods, or when a test needs write-then-read.

Both are hand-rolled `final class`es in the test target. Mark one `@unchecked Sendable` only when it genuinely crosses an actor boundary *and* you've made it thread-safe — a lock, or immutability.

## The network seam

Test `URLSession` code by injecting a session configured with a custom `URLProtocol`:

```swift
final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown)); return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}

let config = URLSessionConfiguration.ephemeral
config.protocolClasses = [MockURLProtocol.self]
let session = URLSession(configuration: config)
```

The static handler is shared mutable state, so suites using it need `@Suite(.serialized)`. Reset it in the test that sets it, not in a shared teardown, or a parallel run will read someone else's handler.

## UI tests

Stub the data behind a launch argument so the run never touches the network:

```swift
app.launchArguments = ["-UITests", "-StubOrders"]
```

Keep UI tests to navigation and visible results — a UI test asserting business logic is a slow, flaky unit test.

## Rules of thumb

- **One concept per test.** Five loosely related assertions in one function is a smell.
- **No real IO in unit tests.** No live `URLSession`, no on-disk SwiftData, no real Keychain.
- **Deterministic time.** Inject `() -> Date` or a `Clock`; never call `Date()` inside the type under test.
- **Name tests as sentences** — `loadMovesFromLoadingToLoaded()`, or a `@Test("...")` description.

## Don'ts

- **No `XCTestExpectation` / `wait(for:)`** in new async tests — `await` the thing.
- **No `Thread.sleep`.** If you're waiting on async work, await it; if you're waiting on a UI element, `waitForExistence(timeout:)`.
- **No test that depends on another test's side effects.** Swift Testing runs suites in parallel by default.
- **No `#expect(true)`.** A test that can't fail is a liability with a green checkmark.
