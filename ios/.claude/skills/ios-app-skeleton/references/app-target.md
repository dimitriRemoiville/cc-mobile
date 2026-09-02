# Reference — `Sources/App/`

The app target: entry point, composition root, and the live implementations of the `AppCore` protocols (`URLSessionAPIClient`, `KeychainStoreLive`). This is the only place that knows about concrete frameworks and the only place allowed to construct dependencies. Loaded at execution-order step 5.

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
