---
name: ios-security
description: iOS security patterns — App Transport Security, URLSession certificate pinning, Keychain ACLs, biometric gating, sandbox hardening, DeviceCheck / App Attest. Load whenever adding auth, secrets, or network calls crossing a trust boundary.
---

# iOS security

## App Transport Security

ATS is on by default and should stay that way. Never add `NSAllowsArbitraryLoads = true` in production `Info.plist`. If you absolutely need cleartext for a dev host:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict><key>NSExceptionAllowsInsecureHTTPLoads</key><true/></dict>
    </dict>
</dict>
```

Scope exceptions to the specific domain, and gate the whole Info.plist variant behind a debug build configuration.

## Certificate pinning

Pin the SPKI, not the full cert. Keep at least two pins (current + next) and ship the rotation pin before the server rotates.

```swift
final class PinningDelegate: NSObject, URLSessionDelegate {
    private let pinnedSPKISha256: Set<Data>

    init(pins: [String]) {
        self.pinnedSPKISha256 = Set(pins.compactMap { Data(base64Encoded: $0) })
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let trust = challenge.protectionSpace.serverTrust,
            let cert = SecTrustGetCertificateChain(trust) as? [SecCertificate],
            let leaf = cert.first
        else {
            completionHandler(.cancelAuthenticationChallenge, nil); return
        }

        let key = SecCertificateCopyKey(leaf)!
        let spki = SecKeyCopyExternalRepresentation(key, nil)! as Data
        let hash = Data(SHA256.hash(data: spki))

        if pinnedSPKISha256.contains(hash) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

let session = URLSession(configuration: .default, delegate: PinningDelegate(pins: [
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
    "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",
]), delegateQueue: nil)
```

## App Attest / DeviceCheck

For "is this really our app, unmodified, running on a real device" proofs:

```swift
import DeviceCheck

Task {
    guard DCAppAttestService.shared.isSupported else { return }
    let keyId = try await DCAppAttestService.shared.generateKey()
    let challenge = try await backend.requestAttestChallenge()
    let attestation = try await DCAppAttestService.shared.attestKey(keyId, clientDataHash: challenge.hash)
    try await backend.registerAttestation(keyId: keyId, attestation: attestation)
}
```

Every subsequent sensitive request signs with the same `keyId` via `generateAssertion`. Server verifies with Apple's public keys.

Never use this as a local anti-tamper signal — always verify server-side.

## Biometric gating

Keychain items can require user presence at read time:

```swift
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    [.biometryCurrentSet],
    nil
)!
```

Reading such an item prompts Face ID / Touch ID. `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)` for explicit pre-authentication.

Use `biometryCurrentSet` (not `.userPresence`) when you want the key to invalidate on biometric re-enrollment.

## Secrets in binary

Don't bundle OAuth client secrets, API keys, or signing keys in the app. Client-side secrets always leak. If a third-party SDK requires one, use an intermediary proxy on your backend.

If you must ship a public key for verification (fine, they're public), store in a `.xcconfig` with `$(VARIABLE)` substitution, not hard-coded in Swift.

## Sandbox hardening

- `Info.plist`: don't claim entitlements you don't use (camera, mic, contacts). Every extra prompt is attack surface and a review risk.
- Shared containers (App Group) get strict file protection: `NSFileProtectionCompleteUntilFirstUserAuthentication` at minimum.
- Files with user secrets: `NSFileProtectionComplete` (not accessible when locked).

```swift
try data.write(to: url, options: [.completeFileProtection])
```

## URL scheme + universal link hijacking

- Universal links require a server-side `apple-app-site-association` file. Never rely on a custom URL scheme for sensitive callbacks (OAuth, etc.) — schemes are not exclusive.
- Validate `UIApplication`'s open URL source: which app opened us, which URL, and what state the app was in.

## WebKit

- `WKWebView` defaults are safe; keep them.
- User-content JS messaging: validate every `WKScriptMessage` body type. Never `eval()` raw.
- For third-party OAuth flows, use `ASWebAuthenticationSession` (not `WKWebView`) so the user sees Apple's chrome and cookies stay in Safari's jar.

## Logging

- `os_log` with private modifiers by default. `%{public}@` for safe strings only.
- No token, PII, or crash-dumped URL in logs.

## Hard nos

- No `NSAllowsArbitraryLoads = true` in release Info.plist.
- No accepting any server trust (`SecTrustEvaluate*` short-circuit).
- No storing tokens in `UserDefaults`.
- No `WKWebView` rendering arbitrary user HTML with `allowingReadAccessTo: url` pointing at the app container.
- No `print(token)` "just to debug".
- No running OAuth code exchange in the client — use PKCE through a backend.
