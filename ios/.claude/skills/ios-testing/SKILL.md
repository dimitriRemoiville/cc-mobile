---
name: ios-testing
description: Testing patterns used in this project — Swift Testing (@Test / #expect) for unit and integration, async tests with Swift Concurrency, hand-rolled fakes, and XCTest for UI automation. Load when writing, updating, or debugging tests of any kind.
---

# Testing playbook (iOS)

## Frameworks

- **Unit / integration:** **Swift Testing** (`import Testing`, `@Test`, `@Suite`, `#expect`, `#require`). Apple's modern framework — use it for new test targets.
- **UI / E2E:** **XCTest** (`XCUIApplication`). Swift Testing doesn't yet cover UI automation.
- **Async:** Native Swift Concurrency — `async` test functions, `await`, no `XCTestExpectation` needed for new code.
- **Fakes / Mocks:** hand-rolled. Protocols + `Mock…` / `Stub…` / `Fake…` types. Mocking libraries exist but aren't idiomatic in Swift.

## Where tests live

```
Tests/               # Swift Testing unit + integration tests
UITests/             # XCTest UI automation
```

## Use case tests (pure Swift)

```swift
import Testing
@testable import App

@Suite("SubmitOrderUseCase")
struct SubmitOrderUseCaseTests {
    @Test("returns order when repository accepts the submission")
    func returnsOrderOnSuccess() async throws {
        let orders = StubOrderRepository(result: .success(.sample))
        let submit = SubmitOrderUseCase(orders: orders, now: { .distantPast })

        let order = try await submit(.sample)

        #expect(order.id == Order.sample.id)
    }

    @Test("throws network when repository fails")
    func throwsNetworkOnFailure() async {
        let orders = StubOrderRepository(result: .failure(DomainError.network(code: 500)))
        let submit = SubmitOrderUseCase(orders: orders, now: { .distantPast })

        await #expect(throws: DomainError.self) {
            _ = try await submit(.sample)
        }
    }
}
```

Notes:
- `@Suite("Name")` groups related tests.
- `@Test` takes an optional description; the function name is the fallback.
- `#expect(condition)` for soft assertions; `#require(condition)` when continuing would be pointless if the check fails.

## View model tests

View models are `@MainActor`, so suites need to hop to the main actor:

```swift
@Suite("ProfileViewModel")
@MainActor
struct ProfileViewModelTests {
    @Test
    func loadTransitionsFromLoadingToLoaded() async {
        let useCase = StubGetProfileUseCase(result: .success(.sample))
        let model = ProfileViewModel(getProfile: useCase)

        #expect(model.state == .loading)
        await model.load()
        #expect(model.state == .loaded(.sample))
    }

    @Test
    func loadTransitionsToErrorOnFailure() async {
        let useCase = StubGetProfileUseCase(result: .failure(DomainError.network(code: 500)))
        let model = ProfileViewModel(getProfile: useCase)

        await model.load()

        guard case .error = model.state else {
            Issue.record("expected .error, got \(model.state)")
            return
        }
    }
}
```

## Hand-rolled fakes (pattern)

```swift
final class StubOrderRepository: OrderRepository {
    let result: Result<Order, Error>
    init(result: Result<Order, Error>) { self.result = result }
    func get(id: OrderID) async throws -> Order { try result.get() }
}

final class FakeOrderRepository: OrderRepository, @unchecked Sendable {
    var orders: [OrderID: Order] = [:]
    func get(id: OrderID) async throws -> Order {
        guard let o = orders[id] else { throw DomainError.notFound }
        return o
    }
}
```

- **Stubs** return a scripted answer.
- **Fakes** have working-ish in-memory behaviour; prefer them for protocols with > 2 methods.
- Mark fakes `@unchecked Sendable` only when they're used across actor boundaries and you're sure they're thread-safe.

## Testing URLSession code

Inject a `URLSession` that uses a custom `URLProtocol`:

```swift
final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else { fatalError("no handler") }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// in the test:
let config = URLSessionConfiguration.ephemeral
config.protocolClasses = [MockURLProtocol.self]
let session = URLSession(configuration: config)
MockURLProtocol.handler = { _ in
    (HTTPURLResponse(url: .init(string: "x")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
     Data(#"{"id":"abc"}"#.utf8))
}
```

## UI tests (XCTest)

```swift
final class OrderFlowUITests: XCTestCase {
    func test_user_can_view_order_detail() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITests", "-StubOrders"]
        app.launch()

        app.buttons["Orders"].tap()
        XCTAssertTrue(app.staticTexts["Order #123"].waitForExistence(timeout: 2))
    }
}
```

- Stub data behind a launch argument so the UI test doesn't hit the network.
- Keep UI tests focused on navigation + visible results — leave logic testing to Swift Testing.

## Rules of thumb

- **One concept per test.** Long tests with five loosely-related assertions are a smell.
- **No real IO in unit tests.** No real `URLSession`, no real SwiftData. Use fakes.
- **Deterministic time.** Inject a `() -> Date` or `Clock` rather than calling `Date()`.
- **Name tests as sentences.** `func returnsOrderOnSuccess()` or `@Test("returns order when repository accepts")`.

## Run tests

```bash
# Xcode scheme:
xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=iPhone 15'

# Just one suite:
xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AppTests/SubmitOrderUseCaseTests
```

## Don'ts

- No `XCTestExpectation` / `wait(for:)` in new async tests — use `await`.
- No `Thread.sleep(forTimeInterval:)` — if you're waiting on async work, `await` it.
- No test that depends on another test's side effects.
- No `#expect(true)` or `XCTAssert(true)` — a passing test that never fails is a liability.
