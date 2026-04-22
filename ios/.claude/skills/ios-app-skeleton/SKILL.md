---
name: ios-app-skeleton
description: Authoritative blueprint for scaffolding a brand-new iOS app with this project's conventions. Used by /init-ios-app. Contains every file template, placeholder list, feature-flag block, and the procedure to emit a runnable splash.
---

# iOS app skeleton

Template registry consumed by `/init-ios-app`. Substitute placeholders; do not improvise.

## Placeholders

| Placeholder | Meaning | Example |
|---|---|---|
| `{{APP_NAME}}` | Xcode/SPM product name, UpperCamelCase | `MyApp` |
| `{{BUNDLE_ID}}` | Bundle identifier | `com.example.myapp` |
| `{{APP_DISPLAY_NAME}}` | Human-facing name | `My App` |
| `{{ORG_NAME}}` | Organization name in project metadata | `Example Inc.` |

## Feature flags

| Flag | Adds |
|---|---|
| `INCLUDE_SWIFTDATA` | `Sources/AppCore/Persistence/` + `@Model` types + container boot |
| `INCLUDE_FIREBASE` | Firebase SPM deps + `FirebaseApp.configure()` wiring, plist reminder |

## Execution order

1. Create `{{APP_NAME}}/` directory.
2. Write `Package.swift`, `.swiftformat`, `.gitignore`, `README.md`.
3. Write `Sources/AppCore/` (domain types, protocols).
4. Write `Sources/AppFeatures/` (Splash feature, typed destinations).
5. Write `Sources/App/` (composition root, URLSession client, Keychain, App entry).
6. Write `Tests/AppCoreTests/` + `Tests/AppFeaturesTests/`.
7. Write `project.yml` for xcodegen (or document the manual Xcode setup).
8. `swift build`, `swift test`.
9. (If xcodegen present) `xcodegen generate`, `xcodebuild build`.
10. Emit manual setup note (signing, schemes, Firebase plist).

---

## Root files

### `Package.swift`

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "{{APP_NAME}}",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "AppCore", targets: ["AppCore"]),
        .library(name: "AppFeatures", targets: ["AppFeatures"]),
    ],
    dependencies: [
        // INCLUDE_FIREBASE:
        // .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "<latest-stable>"),
    ],
    targets: [
        .target(
            name: "AppCore",
            path: "Sources/AppCore"
        ),
        .target(
            name: "AppFeatures",
            dependencies: ["AppCore"],
            path: "Sources/AppFeatures"
        ),
        .testTarget(
            name: "AppCoreTests",
            dependencies: ["AppCore"],
            path: "Tests/AppCoreTests"
        ),
        .testTarget(
            name: "AppFeaturesTests",
            dependencies: ["AppFeatures"],
            path: "Tests/AppFeaturesTests"
        ),
    ]
)
```

### `.swiftformat`

```
--swiftversion 6.0
--indent 4
--maxwidth 120
--wraparguments before-first
--wrapparameters before-first
--wrapcollections before-first
--stripunusedargs closure-only
```

### `.gitignore`

```
.DS_Store
.build/
.swiftpm/
Package.resolved
*.xcodeproj
*.xcworkspace
xcuserdata/
DerivedData/
*.hmap
*.ipa
*.dSYM.zip
GoogleService-Info.plist
```

---

## `Sources/AppCore/`

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

---

## `Sources/AppFeatures/`

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

---

## `Sources/App/` (app target emitted separately; Xcode-backed)

### `{{APP_NAME}}App.swift`

```swift
import SwiftUI
import AppCore
import AppFeatures
// INCLUDE_FIREBASE: import FirebaseCore

@main
struct {{APP_NAME}}App: App {
    init() {
        // INCLUDE_FIREBASE: FirebaseApp.configure()
        _ = CompositionRoot.shared
    }

    var body: some Scene {
        WindowGroup {
            AppNavigation()
        }
    }
}
```

### `CompositionRoot.swift`

```swift
import Foundation
import AppCore

@MainActor
final class CompositionRoot {
    static let shared = CompositionRoot()

    let apiClient: APIClient
    let keychain: KeychainStore

    private init() {
        let baseURL = URL(string: "https://example.invalid/")!
        self.apiClient = URLSessionAPIClient(baseURL: baseURL)
        self.keychain = KeychainStoreLive(service: "{{BUNDLE_ID}}")
    }
}
```

### `URLSessionAPIClient.swift`

```swift
import Foundation
import AppCore

final class URLSessionAPIClient: APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    func get<T: Decodable & Sendable>(_ path: String) async -> Outcome<T> {
        let url = baseURL.appendingPathComponent(path)
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.unknown("non-HTTP response"))
            }
            switch http.statusCode {
            case 200...299:
                let value = try decoder.decode(T.self, from: data)
                return .success(value)
            case 401: return .failure(.unauthorized)
            case 404: return .failure(.notFound)
            case 500...599: return .failure(.server(code: http.statusCode))
            default: return .failure(.unknown("HTTP \(http.statusCode)"))
            }
        } catch let urlError as URLError {
            return .failure(.network(underlying: urlError.localizedDescription))
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }
}
```

### `KeychainStoreLive.swift`

```swift
import Foundation
import Security
import AppCore

final class KeychainStoreLive: KeychainStore {
    private let service: String

    init(service: String) { self.service = service }

    func set(_ value: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = value
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    func get(_ key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        switch status {
        case errSecSuccess: return out as? Data
        case errSecItemNotFound: return nil
        default: throw KeychainError.unhandled(status)
        }
    }

    func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }

    enum KeychainError: Error { case unhandled(OSStatus) }
}
```

---

## INCLUDE_SWIFTDATA additions

Add to `Package.swift` targets only if iOS 17+ (already satisfied by iOS 18 default).

### `Sources/AppCore/Persistence/SchemaV1.swift`

```swift
import Foundation
import SwiftData

public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    public static var models: [any PersistentModel.Type] { [Sample.self] }

    @Model
    public final class Sample {
        @Attribute(.unique) public var id: UUID
        public var label: String
        public init(id: UUID = UUID(), label: String) {
            self.id = id
            self.label = label
        }
    }
}
```

### `Sources/App/PersistenceContainer.swift`

```swift
import Foundation
import SwiftData
import AppCore

enum PersistenceContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration("app", schema: schema)
        return try ModelContainer(for: schema, configurations: config)
    }
}
```

## INCLUDE_FIREBASE additions

In `Package.swift`, add Firebase SPM as a dependency and attach `FirebaseAnalytics`, `FirebaseCrashlytics` products to the `App` target.

In `{{APP_NAME}}App.swift`, the `FirebaseApp.configure()` call in `init()` is active (uncommented).

Per-scheme `GoogleService-Info.plist`:
- dev → `GoogleService-Info-Dev.plist`.
- prod → `GoogleService-Info-Prod.plist`.
- Use a build-phase copy script that picks the right plist per configuration:

```sh
cp "${SRCROOT}/Config/GoogleService-Info-${CONFIGURATION}.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
```

---

## Tests

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

---

## `project.yml` (xcodegen)

Emit this only if the user has `xcodegen` installed (`which xcodegen`). Otherwise print the equivalent manual Xcode steps.

```yaml
name: {{APP_NAME}}
options:
  bundleIdPrefix: {{BUNDLE_ID}}
  deploymentTarget:
    iOS: "18.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
    DEVELOPMENT_TEAM: ""
packages:
  Local:
    path: .
targets:
  {{APP_NAME}}:
    type: application
    platform: iOS
    sources:
      - Sources/App
    dependencies:
      - package: Local
        product: AppCore
      - package: Local
        product: AppFeatures
    info:
      path: Sources/App/Info.plist
      properties:
        UILaunchScreen: {}
        CFBundleDisplayName: {{APP_DISPLAY_NAME}}
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: {{BUNDLE_ID}}
```

---

## Hard rules

- **Swift 6 concurrency on**. Sendable types, `@MainActor` on view models that touch UI, no `@unchecked Sendable` without justification in a comment.
- **No Storyboards, no XIBs.** SwiftUI only.
- **No Objective-C bridging header** unless you truly need a C library.
- **No singletons other than `CompositionRoot`**. Features receive dependencies by initializer injection.
- **No direct `URLSession.shared.data(from:)` in feature code.** Always go through the `APIClient` protocol.
- **Keychain access goes through `KeychainStore`**. Never call `SecItemAdd` from a view model.
- **Typed destinations** — never navigate by string route.
- **SPM first**, Xcode project is just the shell that embeds the package. Don't add app-target files outside `Sources/App/` if you can avoid it.
- **`@Observable`** (Observation framework) for view models, not `ObservableObject`. Min target is iOS 17+ anyway.
- **`#Preview` macro** — no `PreviewProvider` class bodies in new code.

## Post-scaffold manual steps

```
Scaffold complete. Next steps:

☐ Open {{APP_NAME}}.xcodeproj (or the workspace you'll create).
☐ Signing & Capabilities → set your Team for the App target.
☐ Duplicate the default scheme into `dev` + `prod`, set scheme arguments for debug-only logs.
☐ [if Firebase] drop GoogleService-Info-Dev.plist / GoogleService-Info-Prod.plist into Config/, enable the copy-phase script.
☐ [if SwiftData] call PersistenceContainer.make() in App init and inject via .modelContainer().
☐ Replace Splash with your first real feature.

Build it:
  swift build
  swift test
  xcodebuild -scheme {{APP_NAME}} -destination 'platform=iOS Simulator,name=iPhone 15' build test
```
