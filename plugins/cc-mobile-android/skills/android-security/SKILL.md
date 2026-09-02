---
name: android-security
description: Project-specific Android security conventions — Tink over `EncryptedSharedPreferences`, the cert-pinning rotation rule, the no-TrustAllCerts-even-in-debug hard-no, and the project's debug/release discipline. Load whenever adding auth, secrets, or network calls that cross a trust boundary.
---

# Android security (project delta)

For the canonical patterns — Android Keystore, Tink Aead bootstrap, Network Security Config XML, OkHttp `CertificatePinner` setup, `androidx.biometric` flow, Play Integrity request shape, WebView hardening, Intent hardening — read [`developer.android.com/privacy-and-security`](https://developer.android.com/privacy-and-security). This file documents only this project's conventions on top of those.

## When this applies

Stack-agnostic principles below work for any Android app. The OkHttp-pinning subsection assumes OkHttp; for **Ktor**, apply the same pinning rules via `engine { config { sslSocketFactory = ... } }` or platform engine config. Apps still on `EncryptedSharedPreferences` (deprecated) can keep it for non-token data; new code lands on Tink.

## Secrets at rest — Tink, not ESP

**`EncryptedSharedPreferences` is deprecated** (`androidx.security:security-crypto` 1.1.0-alpha was withdrawn). Project canonical: **Tink Aead with the master key in the Android Keystore**. Bootstrap once in a `@Singleton`; store ciphertext blobs in DataStore / Room / files — the key never leaves the Keystore. Existing ESP callers can stay put for non-sensitive flags but should migrate tokens off it.

This alignment is enforced across three places in the plugin:
- `android-security-reviewer` flags ESP as deprecated and recommends Tink migration.
- `datastore-preferences` hard-no points at Tink for any secret storage.
- This skill is the canonical source.

If you find guidance contradicting Tink-first in any of those three, file it as a bug.

## Cert pinning — rotation rule

Pin the **intermediate or leaf SPKI** (not the root CA — rotates too often) and **always ship at least two pins** (current + next). When the server rotates, the app must already trust the next pin **before** the rotation happens. Otherwise a routine cert rotation bricks every installed copy.

Stage the next pin one release ahead of the server's planned rotation. Treat the rotation pin as a release-blocking item, not a cleanup task.

## Biometric

Use `androidx.biometric` with `setAllowedAuthenticators(BIOMETRIC_STRONG or DEVICE_CREDENTIAL)`. **Never `setDeviceCredentialAllowed`** — it's deprecated. Gate secret decryption on a Keystore key bound to the biometric prompt (`CryptoObject(cipherBoundToKey)`); a successful prompt is the only way the cipher becomes usable.

## Play Integrity

Use Play Integrity for anti-tamper / anti-bot. **Don't roll a `SafetyNet` equivalent** — SafetyNet is shut down. The token comes back to the client but **the server verifies it** via Google's Play Integrity decryption + verification API. The client must never make trust decisions from a locally-decoded token.

## Network Security Config — release shape

`<base-config cleartextTrafficPermitted="false">` in `res/xml/network_security_config.xml`, plus a `<domain-config>` that permits cleartext only for `localhost` / `10.0.2.2` (emulator). Wire via `android:networkSecurityConfig` in the manifest. The reviewer flags any `cleartextTrafficPermitted="true"` outside the localhost domain config.

## Debug / release discipline (project rules)

- `BuildConfig.DEBUG`-gated verbose logging only. No `Log.d(tag, json)` paths reachable in release.
- `minifyEnabled = true` + `shrinkResources = true` on release.
- `proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")`.
- Never override `android:debuggable` — Gradle handles it per build type.
- `allowBackup="false"` is the default in the scaffold. If you flip it to `true`, you **must** ship `android:fullBackupContent` excluding the keystore prefs and any token storage.

## Hard nos

- **No tokens in `SharedPreferences`.** Not encrypted ones (ESP is deprecated). Not the plain kind. Not "just for dev." Tink-backed ciphertext only.
- **No `TrustAllCerts` / `HostnameVerifier { _, _ -> true }`** — not even behind a debug flag. Use Network Security Config for localhost exceptions. The reviewer rejects any `BuildConfig.DEBUG`-gated trust bypass; debug builds hitting prod-looking endpoints have shipped certs in real incidents.
- **No `setAllowUniversalAccessFromFileURLs(true)`** on WebView. Use `WebViewAssetLoader` for local assets.
- **No `getIntent()?.extras?.get("token")` trust.** Validate type + origin every time.
- **No `FLAG_MUTABLE`** on `PendingIntent` (target SDK 31+ requires explicit mutability; default to `FLAG_IMMUTABLE`).
- **No `exported="true"`** by default on Activity / Service / Receiver — opt in deliberately, document why.
- **No PII or tokens in logs.** Crashlytics breadcrumbs included.
- **No dynamic code loading from network.** No exceptions.
