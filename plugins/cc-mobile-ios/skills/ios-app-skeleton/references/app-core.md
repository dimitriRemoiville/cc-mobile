# Reference — `Sources/AppCore/`

Framework-free domain layer: the `Outcome` result type, the `DomainError` taxonomy, and the `APIClient` / `KeychainStore` protocols that features depend on. No SwiftUI, no URLSession, no Security-framework calls here — only Foundation. Keeping this target UI-free is what lets `AppCoreTests` run without a simulator. Loaded at execution-order step 3.

### `Outcome.swift`

```swift
import Foundation

public enum Outcome<Success> {
    case success(Success)
    case failure(DomainError)
}

public extension Outcome {
    func map<T>(_ transform: (Success) -> T) -> Outcome<T> {
        switch self {
        case .success(let value): return .success(transform(value))
        case .failure(let error): return .failure(error)
        }
    }
}
```

### `DomainError.swift`

```swift
import Foundation

public enum DomainError: Error, Equatable, Sendable {
    case network(underlying: String? = nil)
    case unauthorized
    case notFound
    case server(code: Int)
    case unknown(String? = nil)
}
```

### `APIClient.swift`

```swift
import Foundation

public protocol APIClient: Sendable {
    func get<T: Decodable & Sendable>(_ path: String) async -> Outcome<T>
}
```

### `KeychainStore.swift`

```swift
import Foundation

public protocol KeychainStore: Sendable {
    func set(_ value: Data, for key: String) throws
    func get(_ key: String) throws -> Data?
    func delete(_ key: String) throws
}
```
