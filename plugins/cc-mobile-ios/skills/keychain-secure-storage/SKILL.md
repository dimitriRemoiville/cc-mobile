---
name: keychain-secure-storage
description: Keychain patterns for this iOS project — a small wrapper for tokens/secrets, access control via biometric or passcode, sharing across app group / Keychain groups, keychain-sharing with the iCloud keychain, migration to/from UserDefaults. Load whenever adding auth tokens, passcodes, or any on-device secret.
---

# Keychain secure storage

## One wrapper, one surface

Never scatter `SecItemAdd` / `SecItemCopyMatching` across the codebase. One injected protocol, one concrete type:

```swift
protocol SecureStore: Sendable {
    func read(_ key: String) throws -> Data?
    func write(_ key: String, value: Data, accessible: KeychainAccessibility) throws
    func delete(_ key: String) throws
}

enum KeychainAccessibility {
    case whenUnlockedThisDeviceOnly
    case whenPasscodeSetThisDeviceOnly
    case afterFirstUnlockThisDeviceOnly

    var rawAttr: CFString {
        switch self {
        case .whenUnlockedThisDeviceOnly: return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .whenPasscodeSetThisDeviceOnly: return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        case .afterFirstUnlockThisDeviceOnly: return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
    }
}
```

## Concrete implementation

```swift
struct KeychainStore: SecureStore {
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier!) { self.service = service }

    func write(_ key: String, value: Data, accessible: KeychainAccessibility) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        let attrs: [CFString: Any] = [
            kSecValueData: value,
            kSecAttrAccessible: accessible.rawAttr,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
            if updateStatus != errSecSuccess { throw KeychainError(status: updateStatus) }
        case errSecItemNotFound:
            var add = query; add.merge(attrs) { _, new in new }
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            if addStatus != errSecSuccess { throw KeychainError(status: addStatus) }
        default:
            throw KeychainError(status: status)
        }
    }

    func read(_ key: String) throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: kCFBooleanTrue as Any,
        ]
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        switch status {
        case errSecSuccess: return out as? Data
        case errSecItemNotFound: return nil
        default: throw KeychainError(status: status)
        }
    }

    func delete(_ key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}

struct KeychainError: Error { let status: OSStatus }
```

## Accessibility

Default to `.whenUnlockedThisDeviceOnly`. Escalate when needed:
- Background fetch that must read tokens before user unlock -> `.afterFirstUnlockThisDeviceOnly`.
- User enrolled biometric + requires explicit proof on every read -> `.whenPasscodeSetThisDeviceOnly` + `SecAccessControl` (see below).

**Never** use `kSecAttrAccessibleAlways` or `...WhenUnlocked` (without `ThisDeviceOnly`) — they sync to iCloud Keychain by default and leak to new devices.

## Biometric-gated items

For operations that need user presence (unlock vault, submit payment):

```swift
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    [.userPresence], // or .biometryCurrentSet for stronger enrollment binding
    nil
)!
let attrs: [CFString: Any] = [
    kSecValueData: tokenData,
    kSecAttrAccessControl: access,
]
```

Reads will prompt for Face ID / Touch ID / passcode on demand.

## App groups & Keychain sharing

For a Widget / Share extension reading the same secrets:

1. Add a Keychain sharing entitlement with a group id (`$(AppIdentifierPrefix)com.example.app`).
2. Pass the shared group via `kSecAttrAccessGroup` in every query.
3. Do not share secrets across unrelated apps.

## Migration from UserDefaults

```swift
func migrateTokenFromDefaultsIfNeeded(store: SecureStore) throws {
    guard let token = UserDefaults.standard.string(forKey: "auth_token"),
          let data = token.data(using: .utf8) else { return }
    try store.write("auth_token", value: data, accessible: .whenUnlockedThisDeviceOnly)
    UserDefaults.standard.removeObject(forKey: "auth_token")
}
```

Ship for one release cycle, delete both the migration and the `UserDefaults` leftovers in the next.

## Testing

Inject `SecureStore`. Tests use an in-memory fake:

```swift
final class InMemorySecureStore: SecureStore, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    private let lock = NSLock()
    func read(_ key: String) -> Data? { lock.lock(); defer { lock.unlock() }; return storage[key] }
    func write(_ key: String, value: Data, accessible: KeychainAccessibility) { lock.lock(); defer { lock.unlock() }; storage[key] = value }
    func delete(_ key: String) { lock.lock(); defer { lock.unlock() }; storage.removeValue(forKey: key) }
}
```

Never hit the real Keychain in unit tests. Integration tests on a simulator are fine for the wrapper itself.

## Hard nos

- No storing secrets in `UserDefaults`, plist, or a local file.
- No logging token values, even in debug.
- No `kSecAttrAccessibleAlways*` or the non-`ThisDeviceOnly` variants.
- No hard-coded secrets in the binary. Ship them from a server on first auth.
- No reading Keychain from a `didFinishLaunching` before the app is unlocked — the call fails silently unless `afterFirstUnlock*` is set.
