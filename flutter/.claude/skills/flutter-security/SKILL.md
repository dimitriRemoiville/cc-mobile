---
name: flutter-security
description: Flutter security patterns — secure storage via `flutter_secure_storage`, Dio + cert pinning, App Check, root/jailbreak detection, deep-link validation, WebView hardening, in-app auth flows. Load whenever adding auth, secrets, or network calls crossing a trust boundary.
---

# Flutter security

## Secrets at rest

`flutter_secure_storage` — backed by Keychain (iOS) and Keystore + `EncryptedSharedPreferences` (Android):

```dart
const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
);

Future<void> saveToken(String token) => _storage.write(key: 'auth_token', value: token);
Future<String?> readToken() => _storage.read(key: 'auth_token');
Future<void> clearToken() => _storage.delete(key: 'auth_token');
```

- Always `this_device` accessibility — never `kSecAttrAccessibleAlways` equivalents that sync to iCloud.
- Don't store refresh tokens in `SharedPreferences` / `NSUserDefaults`.
- Wrap behind a `SecureStore` interface so tests can inject a fake.

## Certificate pinning

With Dio via `dio_certificate_pinner` or a custom `HttpClientAdapter`. Pin the SPKI, ship two pins (current + next), rotate one release **before** the server rotates.

```dart
final dio = Dio()
  ..httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient(context: SecurityContext.defaultContext);
      client.badCertificateCallback = (cert, host, port) => false; // no bypass
      return client;
    },
    validateCertificate: (cert, host, port) {
      final pins = <String>{ _currentPin, _nextPin };
      final subjectPublicKeyInfoSha256 = _spkiSha256(cert);
      return pins.contains(subjectPublicKeyInfoSha256);
    },
  );
```

On mobile, prefer `http_certificate_pinning` or SDK-level pinning; the validator must fail closed — `return false` on unknown cert, no exceptions.

## App Check

Pair with Firebase App Check (see [firebase-services](../firebase-services/SKILL.md)) so non-app clients can't call your backend. Server validates the App Check token on each request.

## Root / jailbreak detection

`flutter_jailbreak_detection` gives a best-effort signal. Use it as a **risk signal** (require re-auth, disable payment flows), never as a hard block on a legit user with a custom ROM.

## Deep-link validation

Universal / App Links + Android App Links are the only safe scheme. Custom schemes (`myapp://...`) are not exclusive to your app and can be hijacked.

- Server-hosted `apple-app-site-association` (iOS) and `assetlinks.json` (Android).
- Validate every incoming link's origin before acting:

```dart
bool _isTrusted(Uri uri) {
  if (uri.scheme != 'https') return false;
  return const ['app.example.com', 'example.com'].contains(uri.host);
}
```

Never trust a deep link to reset state, refresh tokens, or navigate to destructive actions without an additional in-app confirmation.

## In-app auth (OAuth)

Use `flutter_appauth` or `firebase_auth`, not a hand-rolled redirect. Reasons:
- Handles PKCE correctly.
- Uses `SFAuthenticationSession` (iOS) / Custom Tabs (Android), so the user sees Apple / Chrome chrome and cookies persist in the right jar.
- Secrets stay on the backend.

```dart
final result = await appAuth.authorizeAndExchangeCode(
  AuthorizationTokenRequest(
    clientId,
    redirectUri,
    discoveryUrl: 'https://auth.example.com/.well-known/openid-configuration',
    scopes: ['openid', 'profile', 'email'],
  ),
);
```

Client secret is not in the binary. PKCE means you don't need one.

## WebView hardening

Use `webview_flutter` or `flutter_inappwebview` carefully:

- `javaScriptMode: JavaScriptMode.disabled` unless the content needs it.
- `setAllowFileAccess(false)`, `setAllowContentAccess(false)`, `setAllowFileAccessFromFileURLs(false)`, `setAllowUniversalAccessFromFileURLs(false)` on Android.
- Inject no JavaScript that ships secrets.
- Prefer `url_launcher` with external browser / Custom Tabs for third-party HTML.

## Logging

- `debugPrint` only in debug: `if (kDebugMode) debugPrint(...)`.
- Never log tokens, URLs containing tokens, PII, or decoded JWT bodies.
- Crashlytics records unhandled errors automatically; scrub identifiers in your `onError` hook if needed.

## Proguard / R8 on Android

`build.gradle.kts`:

```kotlin
android {
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}
```

Keep reflection targets (Firebase, any generated serializer) via rules files.

## iOS hardening

- `Info.plist`: remove unused permissions (camera, mic) — Apple rejects apps that request without use.
- `NSFileProtectionType: NSFileProtectionCompleteUntilFirstUserAuthentication` at minimum; `NSFileProtectionComplete` for highly sensitive files.
- Never ship with `NSAllowsArbitraryLoads`.

## Dependency hygiene

- `dart pub outdated --mode=null-safety`.
- `pub audit` (if your org runs a proxy) or a GitHub Dependabot-equivalent.
- Pin exact versions for anything touching auth / crypto. Use `^x.y.z` for UI-only libs.

## Hard nos

- No storing tokens in `SharedPreferences` / `NSUserDefaults`.
- No `badCertificateCallback = (_, __, ___) => true`, not even behind `kDebugMode`. Use `SecurityContext` with a dev cert instead.
- No `Platform.isIOS || Platform.isAndroid` security gates — a malicious user sees both paths.
- No WebView rendering untrusted HTML with JS enabled.
- No hard-coded OAuth client secrets or API keys in `lib/`.
