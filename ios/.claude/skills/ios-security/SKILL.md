---
name: ios-security
description: iOS security patterns for this project — App Transport Security, SPKI certificate pinning with rotation, Keychain access-control policy, App Attest, secrets handling, file protection, and the WebKit / URL-scheme rules. Load whenever adding auth, secrets, or network calls that cross a trust boundary.
---

# iOS security

## When this applies

Stack-agnostic. ATS, Keychain access control, App Attest, file protection, and the WebKit rules hold for any iOS app regardless of architecture. Two subsections assume a specific stack: the pinning delegate below is written for `URLSession` (with **Alamofire**, use its `ServerTrustManager` with a `PublicKeysTrustEvaluator` — same SPKI principle, different API), and the Keychain notes assume the `KeychainStore` seam from `keychain-secure-storage` (with a wrapper library, verify what accessibility class it defaults to).

## App Transport Security

ATS is on by default and stays on. **`NSAllowsArbitraryLoads = true` never ships.**

If a dev host genuinely needs cleartext, scope the exception to that domain and put it in a **Debug-only `Info.plist` variant**, not the shipping one:

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

## Certificate pinning

**Pin the SPKI hash, not the certificate.** Certificates rotate on their own schedule; the public key usually doesn't, so SPKI pinning survives renewal.

**Ship at least two pins — current and next — before the server rotates.** A single pin turns a routine server-side rotation into a remote kill switch for every installed copy of the app, with no way to fix it but an App Store release.

```swift
final class PinningDelegate: NSObject, URLSessionDelegate {
    private let pinned: Set<Data>   // SHA-256 of the SPKI

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let trust = challenge.protectionSpace.serverTrust,
            let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
            let leaf = chain.first,
            let key = SecCertificateCopyKey(leaf),
            let spki = SecKeyCopyExternalRepresentation(key, nil) as Data?
        else {
            completionHandler(.cancelAuthenticationChallenge, nil); return
        }

        if pinned.contains(Data(SHA256.hash(data: spki))) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
```

Pin auth and payment endpoints. Pinning every endpoint including third-party CDNs multiplies the rotation risk for no additional protection.

## Secrets

**Don't ship OAuth client secrets, API keys, or signing keys in the app.** Anything in the bundle is extractable; obfuscation buys minutes. If a third-party SDK demands a secret, proxy the call through your backend.

Values that are genuinely public (a verification public key, a bundle-scoped analytics id) go in an `.xcconfig` with `$(VARIABLE)` substitution, not hard-coded in Swift — that keeps per-environment values out of the source and out of `git` history.

**No OAuth code exchange in the client.** PKCE, with the exchange on your backend.

## Keychain access control

The policy lives in `keychain-secure-storage`. The two rules the reviewer enforces here:

- **`ThisDeviceOnly` accessibility classes only.** The others restore onto a different device from an encrypted backup. `kSecAttrAccessibleAlways` is deprecated and is a finding on sight.
- **`.biometryCurrentSet`, not `.userPresence`,** for anything that authorises value — it invalidates when a new biometric is enrolled, which is exactly the passcode-then-add-my-face attack. `.userPresence` also accepts the passcode, defeating the point.

## App Attest

For "is this really our unmodified app on a real device":

```swift
guard DCAppAttestService.shared.isSupported else { return }
let keyId = try await DCAppAttestService.shared.generateKey()
let challenge = try await backend.requestAttestChallenge()
let attestation = try await DCAppAttestService.shared.attestKey(keyId, clientDataHash: challenge.hash)
try await backend.registerAttestation(keyId: keyId, attestation: attestation)
```

Subsequent sensitive requests sign with `generateAssertion`. **Verification is server-side, against Apple's root — always.** An attestation the client checks itself proves nothing, because a client that can be modified can be modified to skip the check.

## File protection

- Files holding user secrets: `.completeFileProtection` (unreadable while locked).
- App Group shared containers: `NSFileProtectionCompleteUntilFirstUserAuthentication` at minimum.
- Don't declare entitlements the app doesn't use — camera, microphone, contacts. Each one is attack surface and a review question.

## URL schemes and universal links

**Custom URL schemes are not exclusive** — any app can register the same scheme and intercept the callback. Never use one for an OAuth redirect or any sensitive callback; use a universal link backed by an `apple-app-site-association` file.

When handling an inbound URL, validate the source application and the app's current state before acting on it.

## WebKit

- **Use `ASWebAuthenticationSession` for third-party auth flows**, never a `WKWebView`. The user sees Safari's chrome and the credentials never pass through your process.
- Content JavaScript is controlled per-navigation via `WKWebpagePreferences.allowsContentJavaScript` (iOS 14+). `WKPreferences.javaScriptEnabled` is deprecated — code still setting it is both stale and applying the setting more broadly than intended.
- **Validate every `WKScriptMessage` body**: check the type and shape before use. A message handler that trusts `message.body` is a script-injection sink.
- Never combine `loadFileURL(_:allowingReadAccessTo:)` pointed at the app container with untrusted content — that hands the page read access to everything in it.

## Logging

`os_log` / `Logger` with private interpolation by default. `%{public}@` is for stable, non-identifying strings only — never a token, an email, or a URL carrying query parameters.

## Hard nos

- **No `NSAllowsArbitraryLoads = true`** in a shipping `Info.plist`.
- **No accepting any server trust** — a `URLSessionDelegate` that calls `completionHandler(.useCredential, URLCredential(trust: trust))` unconditionally disables TLS validation.
- **No tokens in `UserDefaults`**, a plist, or a file.
- **No secret in the binary.**
- **No `print(token)` "just to debug".**
- **No client-side OAuth code exchange.**
